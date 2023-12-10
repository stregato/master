package safe

import (
	"bytes"
	"crypto/aes"
	"encoding/json"
	"fmt"
	"image/jpeg"
	"io"
	"mime"
	"os"
	"path"
	"strings"
	"time"

	"github.com/disintegration/imaging"
	"github.com/godruoyi/go-snowflake"
	"golang.org/x/crypto/blake2b"

	"github.com/stregato/master/woland/core"
	"github.com/stregato/master/woland/security"
	"github.com/stregato/master/woland/sql"
	"github.com/stregato/master/woland/storage"
)

const (
	MaxSizeForCompression = 1 << 26   // 64 MB
	MaxThumbnailSize      = 64 * 1024 // 64 KB
	MaxThumbnailWidth     = 256       // 256 pixels
	MaxThumbnailHeight    = 256       // 256 pixels
	qualityStep           = 10        // Quality reduction step size

	ErrInvalidName = "invalid name: %s should not start with /"
)

type PutOptions struct {
	Progress chan int64 // Progress channel

	Async         bool           `json:"async"`         // Do not wait for the file to be uploaded
	Replace       bool           `json:"replace"`       // Replace all other files with the same name
	ReplaceID     uint64         `json:"replaceId"`     // Replace the file with the specified ID
	UpdateMeta    uint64         `json:"updateMeta"`    // Update the metadata of the file with the specified ID. It does not change the file content
	Tags          []string       `json:"tags"`          // Tags associated with the file
	Thumbnail     []byte         `json:"thumbnail"`     // Thumbnail associated with the file
	AutoThumbnail bool           `json:"autoThumbnail"` // Generate a thumbnail from the file
	ContentType   string         `json:"contentType"`   // Content type of the file
	Zip           bool           `json:"zip"`           // Zip the file if it is smaller than 64MB
	Meta          map[string]any `json:"meta"`          // Metadata associated with the file
	Private       string         `json:"private"`       // Id of the target user in case of private message
}

//func (s *Portal) Put(name string, r io.ReadSeeker, secId uint64, options PutOptions) (Header, error) {

func Put(s *Safe, bucket, name string, src any, options PutOptions, onComplete func(Header, error)) (Header, error) {
	var r io.ReadSeeker
	var err error

	if strings.HasPrefix(name, "/") {
		return Header{}, fmt.Errorf(ErrInvalidName, name)
	}

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

	hash, size, err := getReaderHashAndSize(r)
	if core.IsErr(err, nil, "cannot create hash: %v", err) {
		return Header{}, err
	}

	applyQuota(0.97, s.QuotaGroup, s.store, s.Size, s.Quota, true)

	now := core.Now()
	var bodyId uint64

	if options.UpdateMeta != 0 {
		bodyId = options.UpdateMeta
	} else {
		bodyId = snowflake.ID()
	}

	// store := s.store
	// if options.UpdateMeta == 0 {
	// 	err = store.Write(bodyFile, r, nil)
	// 	if core.IsErr(err, nil, "cannot write body: %v", err) {
	// 		return Header{}, err
	// 	}
	// 	core.Info("Wrote body for %s to %s", name, bodyFile)
	// }

	for _, tag := range options.Tags {
		if !isAlphanumeric(tag) {
			return Header{}, ErrInvalidTag
		}
	}

	if options.AutoThumbnail && len(options.Thumbnail) == 0 {
		options.Thumbnail, err = generateThumbnail(r, MaxThumbnailWidth, MaxThumbnailHeight)
		if core.IsErr(err, nil, "cannot generate thumbnail: %v", err) {
			return Header{}, err
		}
		core.Info("Generated thumbnail for %s, size %d", name, len(options.Thumbnail))
	}

	if options.ContentType == "" {
		options.ContentType = mime.TypeByExtension(path.Ext(name))
		core.Info("Guessed content type for %s: %s", name, options.ContentType)
	}

	headerFile := snowflake.ID()
	attributes := Attributes{
		ContentType: options.ContentType,
		Hash:        hash,
		Thumbnail:   options.Thumbnail,
		Tags:        options.Tags,
		Extra:       options.Meta,
	}

	header := Header{
		Name:       name,
		Size:       size,
		Creator:    s.CurrentUser.Id,
		FileId:     bodyId,
		IV:         core.GenerateRandomBytes(aes.BlockSize),
		PrivateId:  options.Private,
		Attributes: attributes,
		ModTime:    now,
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

	err = insertHeaderOrIgnoreToDB(s.Name, bucket, headerFile, header)
	if core.IsErr(err, nil, "cannot insert header: %v", err) {
		return Header{}, err
	}
	core.Info("Inserted header for %s[%d]", header.Name, header.FileId)

	s.Size += header.Size
	applyQuota(0.95, s.QuotaGroup, s.store, s.Size, s.Quota, false)
	if options.Async {
		if sourceFile != "" {
			core.Info("Async put for %s[%d]", header.Name, header.FileId)
			s.uploadFile <- true
			return header, nil
		} else {
			return header, fmt.Errorf("cannot put async without source file")
		}
	} else {
		return writeToStore(s, bucket, r, headerFile, header, onComplete)
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

func uploadFilesInBackground(s *Safe) {
	rows, err := sql.Query("GET_UPLOADS", sql.Args{"safe": s.Name})
	if core.IsErr(err, nil, "cannot get uploads: %v", err) {
		return
	}

	var headers []Header
	var headerFiles []uint64
	var buckets []string
	for rows.Next() {
		var headerFile uint64
		var bucket string
		var data []byte
		if core.IsErr(rows.Scan(&headerFile, &bucket, &data), nil, "cannot scan file: %v", err) {
			continue
		}
		var header Header
		err = json.Unmarshal(data, &header)
		if core.IsErr(err, nil, "cannot unmarshal header: %v", err) {
			continue
		}
		if uploading[headerFile] {
			core.Info("File %s[%d] is already uploading", header.Name, header.FileId)
			continue
		}
		headers = append(headers, header)
		headerFiles = append(headerFiles, headerFile)
		buckets = append(buckets, bucket)
	}
	rows.Close()

	for i, header := range headers {
		f, err := os.Open(header.SourceFile)
		if !core.IsErr(err, nil, "cannot open source file: %v", err) {
			core.Info("Uploading %s[%d]", header.Name, header.FileId)
			_, err = writeToStore(s, buckets[i], f, headerFiles[i], header, nil)
			f.Close()
		}

		if err != nil && core.Since(header.ModTime) > time.Hour*24*7 {
			_, err = sql.Exec("DELETE_UPLOAD", sql.Args{"safe": s.Name, "headerFile": headerFiles[i], "bucket": buckets[i]})
			if !core.IsErr(err, nil, "cannot delete upload: %v", err) {
				core.Info("Deleted upload %s[%d] after 7 days tries", header.Name, header.FileId)
			}
		}
	}

}

var uploading = make(map[uint64]bool)

//var uploadingLock sync.Mutex

func writeToStore(s *Safe, bucket string, r io.ReadSeeker, headerFile uint64, header Header, onComplete func(Header, error)) (Header, error) {
	uploading[headerFile] = true
	defer delete(uploading, headerFile)

	header.Uploading = false
	store := s.store
	hashedBucket := hashPath(bucket)
	bodyFile := path.Join(s.Name, DataFolder, hashedBucket, BodyFolder, fmt.Sprintf("%d", header.FileId))

	var err error

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
		deleteFile(s.store, s.Name, hashedBucket, file.FileId)
		core.Info("Deleted %s[%d]", file.Name, file.FileId)
	}

	if header.SourceFile != "" {
		header.Downloads = map[string]time.Time{header.SourceFile: core.Now()}
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

	filePath := path.Join(s.Name, DataFolder, hashedBucket, HeaderFolder, fmt.Sprintf("%d", headerFile))
	keyId := s.keystore.LastKeyId
	keyValue := s.keystore.Keys[keyId]
	headersFile := HeadersFile{
		KeyId:   keyId,
		Bucket:  bucket,
		Headers: []Header{header2},
	}
	err = writeHeadersFile(store, s.Name, filePath, keyValue, headersFile)
	if core.IsErr(err, nil, "cannot write header: %v", err) {
		store.Delete(bodyFile)
		return Header{}, err
	}
	core.Info("Wrote header for %s[%d]", header2.Name, header2.FileId)
	err = SetCached(s.Name, store, fmt.Sprintf("data/%s/.touch", hashedBucket), nil, s.CurrentUser.Id)
	if core.IsErr(err, nil, "cannot set touch file: %v", err) {
		return Header{}, err
	}

	err = updateHeaderInDB(s.Name, bucket, header2.FileId, func(h Header) Header {
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

	return header, nil
}

func generateThumbnail(r io.ReadSeeker, maxWidth, maxHeight int) ([]byte, error) {
	_, err := r.Seek(0, io.SeekStart)
	if core.IsErr(err, nil, "cannot seek to start of file: %v", err) {
		return nil, err
	}

	// Decode the image from the provided input
	img, err := imaging.Decode(r)
	if core.IsErr(err, nil, "cannot decode image: %v", err) {
		return nil, fmt.Errorf("failed to decode image: %w", err)
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
