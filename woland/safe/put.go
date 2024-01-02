package safe

import (
	"bytes"
	"crypto/aes"
	"encoding/json"
	"fmt"
	"image"
	"image/jpeg"
	"io"
	"mime"
	"os"
	"path"
	"strings"
	"time"

	"github.com/disintegration/imaging"
	"github.com/godruoyi/go-snowflake"
	"github.com/rwcarlsen/goexif/exif"
	"golang.org/x/crypto/blake2b"

	"github.com/stregato/master/woland/core"
	"github.com/stregato/master/woland/security"
	"github.com/stregato/master/woland/sql"
	"github.com/stregato/master/woland/storage"
)

const (
	MaxSizeForCompression = 1 << 26   // 64 MB
	MaxThumbnailSize      = 64 * 1024 // 64 KB
	MaxThumbnailWidth     = 512       // 512 px
	qualityStep           = 10        // Quality reduction step size

	ErrInvalidName = "invalid name: %s should not start with /"
)

type PutOptions struct {
	Progress chan int64 // Progress channel

	Async          bool           `json:"async"`          // Do not wait for the file to be uploaded
	Replace        bool           `json:"replace"`        // Replace all other files with the same name
	ReplaceID      uint64         `json:"replaceId"`      // Replace the file with the specified ID
	Tags           []string       `json:"tags"`           // Tags associated with the file
	Thumbnail      []byte         `json:"thumbnail"`      // Thumbnail associated with the file
	ThumbnailWidth int            `json:"thumbnailWidth"` // Thumbnail width
	AutoThumbnail  bool           `json:"autoThumbnail"`  // Generate a thumbnail from the file
	ContentType    string         `json:"contentType"`    // Content type of the file
	Zip            bool           `json:"zip"`            // Zip the file if it is smaller than 64MB
	Meta           map[string]any `json:"meta"`           // Metadata associated with the file
	Private        string         `json:"private"`        // Id of the target user in case of private message
}

//func (s *Portal) Put(name string, r io.ReadSeeker, secId uint64, options PutOptions) (Header, error) {

func Put(s *Safe, bucket, name string, src any, options PutOptions, onComplete func(Header, error)) (Header, error) {
	var r io.ReadSeeker
	var err error

	if strings.HasPrefix(name, "/") {
		return Header{}, fmt.Errorf(ErrInvalidName, name)
	}

	now := core.Now()
	var bodyId uint64
	var hash []byte
	var size int64
	var modTime time.Time

	sourceFile, ok := src.(string)

	if ok {
		r, err = os.Open(sourceFile)
		if core.IsErr(err, nil, "cannot open source file: %v", err) {
			return Header{}, err
		}
	} else {
		r, ok = src.(io.ReadSeeker)
		if !ok {
			return Header{}, fmt.Errorf("source must be a filename or io.ReadSeeker: %v", src)
		}
	}
	bodyId = snowflake.ID()
	hash, size, err = getReaderHashAndSize(r)
	if core.IsErr(err, nil, "cannot create hash: %v", err) {
		return Header{}, err
	}

	if options.AutoThumbnail && len(options.Thumbnail) == 0 {
		var width = options.ThumbnailWidth
		if width == 0 {
			width = MaxThumbnailWidth
		}

		options.Thumbnail, err = generateThumbnail(r, width)
		if core.IsErr(err, nil, "cannot generate thumbnail: %v", err) {
			return Header{}, err
		}
		core.Info("Generated thumbnail for %s, size %d", name, len(options.Thumbnail))
	}
	modTime = now

	for _, tag := range options.Tags {
		if !isAlphanumeric(tag) {
			return Header{}, ErrInvalidTag
		}
	}

	if options.ContentType == "" {
		options.ContentType = mime.TypeByExtension(path.Ext(name))
		core.Info("Guessed content type for %s: %s", name, options.ContentType)
	}

	headerId := snowflake.ID()
	attributes := Attributes{
		ContentType: options.ContentType,
		Hash:        hash,
		Thumbnail:   options.Thumbnail,
		Tags:        options.Tags,
		Meta:        options.Meta,
	}

	header := Header{
		Name:       name,
		Size:       size,
		Creator:    s.CurrentUser.Id,
		FileId:     bodyId,
		IV:         core.GenerateRandomBytes(aes.BlockSize),
		PrivateId:  options.Private,
		Attributes: attributes,
		ModTime:    modTime,
		Uploading:  true,
		SourceFile: sourceFile,
		ReplaceId:  options.ReplaceID,
		Replace:    options.Replace,
	}
	if header.PrivateId != "" {
		bodyKey, err := security.DiffieHellmanKey(s.CurrentUser, header.PrivateId)
		if core.IsErr(err, nil, "cannot create diffie hellman key: %v", err) {
			return Header{}, err
		}
		header.BodyKey = bodyKey
		core.Info("Using diffie hellman key for %s", header.Name)
	} else {
		header.BodyKey = core.GenerateRandomBytes(KeySize)
		core.Info("Using random key for %s", header.Name)
	}

	err = insertHeaderOrIgnoreToDB(s.Name, bucket, headerId, header)
	if core.IsErr(err, nil, "cannot insert header: %v", err) {
		return Header{}, err
	}
	core.Info("Inserted header for %s[%d]", header.Name, header.FileId)

	s.Size += header.Size
	//	applyQuota(0.95, s.QuotaGroup, store, s.Size, s.Quota, false)

	if options.Async {
		if sourceFile == "" {
			sourceFile := path.Join(os.TempDir(), fmt.Sprintf("%d.delete", header.FileId))
			f, err := os.Create(sourceFile)
			if core.IsErr(err, nil, "cannot create temp file: %v", err) {
				return Header{}, err
			}
			_, err = io.Copy(f, r)
			if core.IsErr(err, nil, "cannot copy to temp file: %v", err) {
				return Header{}, err
			}
			f.Close()
			header.SourceFile = sourceFile
		}

		core.Info("Async put for %s[%d]", header.Name, header.FileId)
		s.uploadFile <- UploadTask{Bucket: bucket, Header: header, HeaderFile: headerId}
		return header, nil
	} else {
		return writeToStore(s, s.primary, bucket, r, headerId, header, onComplete)
	}
}

func getReaderHashAndSize(r io.ReadSeeker) (hash []byte, size int64, err error) {
	_, err = r.Seek(0, io.SeekStart)
	if err != nil {
		return nil, 0, err
	}

	hasher, err := blake2b.New384(nil)
	if err != nil {
		return nil, 0, err
	}

	if size, err = io.Copy(hasher, r); err != nil {
		return nil, 0, err
	}

	_, err = r.Seek(0, io.SeekStart)
	if err != nil {
		return nil, 0, err
	}

	return hasher.Sum(nil), size, nil
}

type UploadTask struct {
	Bucket     string
	Header     Header
	HeaderFile uint64
}

func uploadFilesInBackground(s *Safe) {
	rows, err := sql.Query("GET_UPLOADS", sql.Args{"safe": s.Name})
	if core.IsErr(err, nil, "cannot get uploads: %v", err) {
		return
	}

	var headers []Header
	var headerIds []uint64
	var buckets []string
	for rows.Next() {
		var headerId uint64
		var bucket string
		var data []byte
		if core.IsErr(rows.Scan(&headerId, &bucket, &data), nil, "cannot scan file: %v", err) {
			continue
		}
		var header Header
		err = json.Unmarshal(data, &header)
		if core.IsErr(err, nil, "cannot unmarshal header: %v", err) {
			continue
		}
		if uploading[headerId] {
			core.Info("File %s[%d] is already uploading", header.Name, header.FileId)
			continue
		}
		headers = append(headers, header)
		headerIds = append(headerIds, headerId)
		buckets = append(buckets, bucket)
	}
	rows.Close()

	for i, header := range headers {
		err = uploadFileInBackground(s, UploadTask{Bucket: buckets[i], Header: header, HeaderFile: headerIds[i]})
		if err != nil && core.Since(header.ModTime) > time.Hour*24*7 {
			_, err = sql.Exec("DELETE_UPLOAD", sql.Args{"safe": s.Name, "headerId": headerIds[i], "bucket": buckets[i]})
			if !core.IsErr(err, nil, "cannot delete upload: %v", err) {
				core.Info("Deleted upload %s[%d] after 7 days tries", header.Name, header.FileId)
			}
		}
	}

}

func uploadFileInBackground(s *Safe, uploadTask UploadTask) error {
	header := uploadTask.Header
	f, err := os.Open(header.SourceFile)
	if core.IsErr(err, nil, "cannot open source file: %v", err) {
		return err
	}
	defer f.Close()
	core.Info("Uploading %s[%d] in %s/%s", header.Name, header.FileId, s.Name, uploadTask.Bucket)

	_, err = writeToStore(s, s.primary, uploadTask.Bucket, f, uploadTask.HeaderFile, header, nil)
	if core.IsErr(err, nil, "cannot write to store: %v", err) {
		return err
	}
	if s.stores[0] != s.primary {
		f.Seek(0, io.SeekStart)
		_, err = writeToStore(s, s.stores[0], uploadTask.Bucket, f, uploadTask.HeaderFile, header, nil)
		core.IsErr(err, nil, "cannot write to secondary store: %v", err)
	}

	core.Info("Uploaded %s[%d]", header.Name, header.FileId)

	if path.Dir(header.SourceFile) == os.TempDir() && strings.HasSuffix(header.SourceFile, ".delete") {
		os.Remove(header.SourceFile)
		core.Info("Deleted %s", header.SourceFile)
	}

	return err
}

var uploading = make(map[uint64]bool)

//var uploadingLock sync.Mutex

func writeToStore(s *Safe, store storage.Store, bucket string, r io.ReadSeeker, headerId uint64, header Header, onComplete func(Header, error)) (Header, error) {
	uploading[headerId] = true
	defer delete(uploading, headerId)

	header.Uploading = false
	hashedBucket := hashPath(bucket)
	bodyFile := path.Join(s.Name, DataFolder, hashedBucket, BodyFolder, fmt.Sprintf("%d", header.FileId))

	var err error

	if r != nil {
		r, err = encryptReader(r, header.BodyKey, header.IV)
		if core.IsErr(err, nil, "cannot create encrypting reader: %v", err) {
			return Header{}, err
		}
		if header.Zip {
			r, err = gzipStream(r)
			if core.IsErr(err, nil, "cannot compress data: %v", err) {
				return Header{}, err
			}
			core.Info("Using compression for file %s", header.Name)
		}

		err = store.Write(bodyFile, r, nil)
		if core.IsErr(err, nil, "cannot write body: %v", err) {
			return Header{}, err
		}
		core.Info("Wrote body for %s to %s", header.Name, bodyFile)
	}

	var deletables []Header
	if header.Replace {
		homonyms, err := ListFiles(s, bucket, ListOptions{Name: header.Name})
		if core.IsErr(err, nil, "cannot list homonyms: %v", err) {
			store.Delete(bodyFile)
			return Header{}, err
		}
		deletables = homonyms
		core.Info("Replacing %d files with name %s", len(homonyms), header.Name)
	}
	if header.ReplaceId != 0 {
		replaceable, err := ListFiles(s, bucket, ListOptions{FileId: header.ReplaceId})
		if core.IsErr(err, nil, "cannot list replaceable: %v", err) {
			store.Delete(bodyFile)
			return Header{}, err
		}
		deletables = append(deletables, replaceable...)
		core.Info("Replacing %d files with id %d", len(replaceable), header.ReplaceId)
	}

	for _, file := range deletables {
		deleteFile(store, s.Name, hashedBucket, file.FileId)
		core.Info("Deleted %s[%d]", file.Name, file.FileId)
	}

	if header.SourceFile != "" {
		header.Downloads = map[string]time.Time{header.SourceFile: core.Now()}
	}

	writeHeader(s, bucket, header, headerId)

	err = updateHeaderInDB(s.Name, bucket, header.FileId, func(h Header) Header {
		h.Uploading = false
		h.Downloads = header.Downloads
		return h
	})
	if core.IsErr(err, nil, "cannot update header: %v", err) {
		return Header{}, err
	}

	if onComplete != nil {
		onComplete(header, err)
	}

	for _, sc := range s.StoreConfigs {
		if sc.Url == store.Url() {
			limit := sc.Quota * 9 / 10
			s.storeSizesLock.Lock()
			s.storeSizes[store.Url()] = s.storeSizes[store.Url()] + header.Size
			if s.storeSizes[store.Url()] > limit {
				core.Info("Enforcing quota on %s in %s because likely exceeding", store.Url(), s.Name)
				s.enforceQuota <- true
			}
			s.storeSizesLock.Unlock()
		}
	}

	return header, nil
}

func writeHeader(s *Safe, bucket string, header Header, headerId uint64) (Header, error) {
	var err error

	if header.PrivateId != "" {
		bodyKey, err := security.DiffieHellmanKey(s.CurrentUser, header.PrivateId)
		if core.IsErr(err, nil, "cannot create diffie hellman key: %v", err) {
			return Header{}, err
		}
		header.BodyKey = bodyKey
		core.Info("Using diffie hellman key for %s", header.Name)
	} else {
		header.BodyKey = core.GenerateRandomBytes(KeySize)
		core.Info("Using random key for %s", header.Name)
	}

	var header2 = header
	if header2.PrivateId != "" {
		// Encrypt attributes before writing to store
		encryptedAttributes, err := encryptHeaderAttributes(header2.BodyKey, header2.IV, header2.Attributes)
		if core.IsErr(err, nil, "cannot encrypt attributes: %v", err) {
			return Header{}, err
		}
		header2.EncryptedAttributes = encryptedAttributes
		header2.Attributes = Attributes{}
		header2.BodyKey = nil
	}

	hashedBucket := hashPath(bucket)
	filePath := path.Join(s.Name, DataFolder, hashedBucket, HeaderFolder, fmt.Sprintf("%d", headerId))
	keyId := s.keystore.LastKeyId
	keyValue := s.keystore.Keys[keyId]
	headersFile := HeadersFile{
		KeyId:   keyId,
		Bucket:  bucket,
		Headers: []Header{header2},
	}
	err = writeHeadersFile(s.primary, s.Name, filePath, keyValue, headersFile)
	if core.IsErr(err, nil, "cannot write header: %v", err) {
		return Header{}, err
	}
	core.Info("Wrote header for %s[%d]", header2.Name, header2.FileId)
	err = SetCached(s.Name, s.primary, fmt.Sprintf("data/%s/.touch", hashedBucket), nil, s.CurrentUser.Id)
	if core.IsErr(err, nil, "cannot set touch file: %v", err) {
		return Header{}, err
	}
	return header, nil
}

func generateThumbnail(r io.ReadSeeker, maxWidth int) ([]byte, error) {
	r.Seek(0, io.SeekStart)
	x, _ := exif.Decode(r)
	_, err := r.Seek(0, io.SeekStart)
	if core.IsErr(err, nil, "cannot seek to start of file: %v", err) {
		return nil, err
	}

	// Decode the image from the provided input
	img, err := imaging.Decode(r)
	if core.IsErr(err, nil, "cannot decode image: %v", err) {
		return nil, fmt.Errorf("failed to decode image: %w", err)
	}

	var maxHeight int
	w := img.Bounds().Dx()
	h := img.Bounds().Dy()
	maxHeight = h * maxWidth / w

	if x != nil {
		orientation := getOrientation(x)
		img = transformImageBasedOnEXIF(img, orientation)
	}

	// Reduce quality or dimensions until the thumbnail size is within the limit
	quality := 100
	for {
		// Generate the thumbnail with the specified dimensions and quality
		thumb := imaging.Thumbnail(img, maxWidth, maxHeight, imaging.Lanczos)
		buffer := new(bytes.Buffer)

		// Encode the thumbnail with the current quality setting
		err = jpeg.Encode(buffer, thumb, &jpeg.Options{Quality: quality})
		if core.IsErr(err, nil, "cannot encode thumbnail: %v", err) {
			return nil, fmt.Errorf("failed to encode thumbnail: %w", err)
		}

		core.Info("Generated thumbnail with quality %d, size %d", quality, len(buffer.Bytes()))
		// Check the size of the thumbnail
		if len(buffer.Bytes()) <= MaxThumbnailSize {
			return buffer.Bytes(), nil
		}

		// Reduce quality by the specified step size
		quality -= qualityStep

		// If the quality reaches 0, reduce the dimensions by 10%
		if quality <= 0 {
			maxWidth = maxWidth * 9 / 10
			maxHeight = maxHeight * 9 / 10
			quality = 100
		}
	}

}

func getOrientation(x *exif.Exif) int {
	orientTag, err := x.Get(exif.Orientation)
	if err != nil {
		return 1 // Default orientation
	}
	orientation, err := orientTag.Int(0)
	if err != nil {
		return 1 // Default orientation
	}
	return orientation
}

func transformImageBasedOnEXIF(img image.Image, orientation int) image.Image {
	switch orientation {
	case 1:
		// normal
		return img
	case 2:
		// horizontally flipped
		return imaging.FlipH(img)
	case 3:
		// rotated 180
		return imaging.Rotate180(img)
	case 4:
		// rotated 180 and flipped horizontally
		return imaging.FlipH(imaging.Rotate180(img))
	case 5:
		// rotated 90 clockwise and flipped vertically
		return imaging.FlipV(imaging.Rotate90(img))
	case 6:
		// rotated 90 clockwise
		return imaging.Rotate270(img)
	case 7:
		// rotated 270 clockwise and flipped vertically
		return imaging.FlipV(imaging.Rotate270(img))
	case 8:
		// rotated 270 clockwise
		return imaging.Rotate90(img)
	default:
		return img
	}
}

func deleteFile(store storage.Store, safeName string, hashedDir string, fileId uint64) error {
	fullName := path.Join(safeName, DataFolder, hashedDir, fmt.Sprintf("%d.b", fileId))
	err := store.Delete(fullName)
	if !core.IsErr(err, nil, "cannot delete file: %v", err) {
		core.Info("Deleted %s[%d] during Put in %s", fullName, fileId, safeName)
	}

	r, err := sql.Exec("SET_DELETED_FILE", sql.Args{
		"safe":   safeName,
		"fileId": fileId,
	})
	if core.IsErr(err, nil, "cannot set deleted file: %v", err) {
		return err
	}
	n, _ := r.RowsAffected()
	if n > 0 {
		core.Info("Marked %s[%d] as deleted in %s", fullName, fileId, safeName)
	} else {
		core.Info("Cannot mark %s[%d] as deleted in %s", fullName, fileId, safeName)
	}

	return nil
}
