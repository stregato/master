package safe

import (
	"bytes"
	"crypto/aes"
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

	Replace       bool           `json:"replace"`       // Replace all other files with the same name
	ReplaceID     uint64         `json:"replaceId"`     // Replace the file with the specified ID
	Tags          []string       `json:"tags"`          // Tags associated with the file
	Thumbnail     []byte         `json:"thumbnail"`     // Thumbnail associated with the file
	AutoThumbnail bool           `json:"autoThumbnail"` // Generate a thumbnail from the file
	ContentType   string         `json:"contentType"`   // Content type of the file
	Zip           bool           `json:"zip"`           // Zip the file if it is smaller than 64MB
	Meta          map[string]any `json:"meta"`          // Metadata associated with the file
	Source        string         `json:"source"`        // Track the source of the file as download location
}

//func (s *Portal) Put(name string, r io.ReadSeeker, secId uint64, options PutOptions) (Header, error) {

func Put(s *Safe, name string, r io.ReadSeeker, options PutOptions) (Header, error) {
	if strings.HasPrefix(name, "/") {
		return Header{}, fmt.Errorf(ErrInvalidName, name)
	}

	dir := hashPath(getDir(name))
	now := core.Now()
	id := snowflake.ID()
	bodyKey := core.GenerateRandomBytes(KeySize)
	iv := core.GenerateRandomBytes(aes.BlockSize)

	var err error
	hash, err := blake2b.New384(nil)
	if core.IsErr(err, nil, "cannot create hash: %v", err) {
		return Header{}, err
	}

	hsr := hashSizeReader(r, hash, options.Progress)
	var r2 io.ReadSeeker = hsr
	bodyFile := path.Join(DataFolder, dir, fmt.Sprintf("%d.b", id))
	if options.Zip {
		r2, err = gzipStream(r2)
		if core.IsErr(err, nil, "cannot compress data: %v", err) {
			return Header{}, err
		}
		core.Info("Using compression for file %s", name)
	}

	r2, err = encryptReader(r2, bodyKey, iv)
	if core.IsErr(err, nil, "cannot create encrypting reader: %v", err) {
		return Header{}, err
	}

	store := s.stores[0]
	err = store.Write(bodyFile, r2, nil)
	if core.IsErr(err, nil, "cannot write body: %v", err) {
		return Header{}, err
	}
	core.Info("Wrote body for %s to %s", name, bodyFile)

	for _, tag := range options.Tags {
		if !isAlphanumeric(tag) {
			return Header{}, ErrInvalidTag
		}
	}

	if options.AutoThumbnail && len(options.Thumbnail) == 0 {
		options.Thumbnail, err = generateThumbnail(r, MaxThumbnailWidth, MaxThumbnailHeight)
		if core.IsErr(err, nil, "cannot generate thumbnail: %v", err) {
			store.Delete(bodyFile)
			return Header{}, err
		}
		core.Info("Generated thumbnail for %s, size %d", name, len(options.Thumbnail))
	}

	if options.ContentType == "" {
		options.ContentType = mime.TypeByExtension(path.Ext(name))
		core.Info("Guessed content type for %s: %s", name, options.ContentType)
	}

	var deletables []Header
	if options.Replace {
		homonyms, err := ListFiles(s, dir, ListOptions{Name: name})
		if core.IsErr(err, nil, "cannot list homonyms: %v", err) {
			store.Delete(bodyFile)
			return Header{}, err
		}
		deletables = homonyms
		core.Info("Replacing %d files with name %s", len(homonyms), name)
	}
	if options.ReplaceID != 0 {
		replaceable, err := ListFiles(s, dir, ListOptions{FileId: options.ReplaceID})
		if core.IsErr(err, nil, "cannot list replaceable: %v", err) {
			store.Delete(bodyFile)
			return Header{}, err
		}
		deletables = append(deletables, replaceable...)
		core.Info("Replacing %d files with id %d", len(replaceable), options.ReplaceID)
	}

	header := Header{
		Name:        name,
		Creator:     s.CurrentUser.Id,
		Size:        hsr.bytesRead,
		Hash:        hash.Sum(nil),
		Zip:         options.Zip,
		Thumbnail:   options.Thumbnail,
		ContentType: options.ContentType,
		Tags:        options.Tags,
		ModTime:     now,
		Meta:        options.Meta,
		FileId:      id,
		BodyKey:     bodyKey,
		IV:          iv,
	}
	err = writeHeaders(store, s.Name, dir, s.keyId, s.keys, []Header{header})
	if core.IsErr(err, nil, "cannot write header: %v", err) {
		store.Delete(bodyFile)
		return Header{}, err
	}
	core.Info("Wrote header for %s[%d]", header.Name, header.FileId)

	for _, file := range deletables {
		deleteFile(store, s.Name, file)
		core.Info("Deleted %s[%d]", file.Name, file.FileId)
	}

	if options.Source != "" {
		stat, err := os.Stat(options.Source)
		if core.IsErr(err, nil, "cannot stat source: %v", err) {
			return Header{}, err
		}
		header.Downloads = map[string]time.Time{options.Source: stat.ModTime()}
		core.Info("Added download location for %s: %s", name, options.Source)
	}
	err = insertHeaderOrIgnoreToDB(s.Name, header)
	core.IsErr(err, nil, "cannot insert header: %v", err)
	core.Info("Inserted header for %s[%d]", header.Name, header.FileId)

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

func deleteFile(store storage.Store, safeName string, header Header) error {
	fullName := path.Join(DataFolder, fmt.Sprintf("%d.b", header.FileId))
	err := store.Delete(fullName)
	if core.IsErr(err, nil, "cannot delete file: %v", err) {
		return err
	}

	_, err = sql.Exec("SET_DELETED_FILE", sql.Args{
		"safe":   safeName,
		"name":   header.Name,
		"fileId": header.FileId,
	})
	if core.IsErr(err, nil, "cannot set deleted file: %v", err) {
		return err
	}

	return nil
}
