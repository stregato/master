package safe

import (
	"bytes"
	"crypto/aes"
	"fmt"
	"image/jpeg"
	"io"
	"mime"
	"path"
	"time"

	"github.com/disintegration/imaging"
	"golang.org/x/crypto/blake2b"

	"github.com/stregato/masterwoland/core"
	"github.com/stregato/masterwoland/sql"
	"github.com/stregato/masterwoland/storage"
)

const (
	MaxSizeForCompression = 1 << 26   // 64 MB
	MaxThumbnailSize      = 64 * 1024 // 64 KB
	MaxThumbnailWidth     = 256       // 256 pixels
	MaxThumbnailHeight    = 256       // 256 pixels
	qualityStep           = 10        // Quality reduction step size
)

type PutOptions struct {
	Progress chan int64 // Progress channel

	Replace       bool           // Replace all other files with the same name
	ReplaceID     uint64         // Replace the file with the specified ID
	Tags          []string       // Tags associated with the file
	Thumbnail     []byte         // Thumbnail associated with the file
	AutoThumbnail bool           // Automatically generate a thumbnail for the file
	ContentType   string         // Content type of the file. When not provided, the content type is determined from the file extension
	Zip           bool           // Zip the file if it is smaller than 64MB
	Meta          map[string]any // Metadata associated with the file
}

func (s *Safe) Put(zoneName, name string, r io.ReadSeeker, options PutOptions) error {
	zone, ok := s.zones[zoneName]
	if !ok {
		return ErrZoneNotExist
	}

	now := core.Now()
	ID := core.NextID(0)
	sub := formatYearMonthDay(now)
	bodyKey := core.GenerateRandomBytes(KeySize)
	iv := core.GenerateRandomBytes(aes.BlockSize)

	var err error
	hash, err := blake2b.New384(nil)
	if core.IsErr(err, "cannot create hash: %v", err) {
		return err
	}

	hsr := hashSizeReader(r, hash, options.Progress)
	var r2 io.ReadSeeker = hsr
	bodyFile := path.Join(zonesDir, zoneName, sub, fmt.Sprintf("%d.b", ID))
	if options.Zip {
		r2, err = gzipStream(r2)
		if core.IsErr(err, "cannot compress data: %v", err) {
			return err
		}
	}

	r2, err = encryptReader(r2, bodyKey, iv)
	if core.IsErr(err, "cannot create encrypting reader: %v", err) {
		return err
	}

	err = s.store.Write(bodyFile, r2, nil)
	if core.IsErr(err, "cannot write body: %v", err) {
		return err
	}

	for _, tag := range options.Tags {
		if !isAlphanumeric(tag) {
			return ErrInvalidTag
		}
	}

	if options.AutoThumbnail && options.Thumbnail == nil {
		options.Thumbnail, err = generateThumbnail(r, MaxThumbnailWidth, MaxThumbnailHeight)
		if core.IsErr(err, "cannot generate thumbnail: %v", err) {
			s.store.Delete(bodyFile)
			return err
		}
	}

	if options.ContentType == "" {
		options.ContentType = mime.TypeByExtension(path.Ext(name))
	}

	var deletables []Header
	if options.Replace {
		homonyms, err := s.List(zoneName, ListOptions{Name: name})
		if core.IsErr(err, "cannot list homonyms: %v", err) {
			s.store.Delete(bodyFile)
			return err
		}
		deletables = homonyms
	}
	if options.ReplaceID != 0 {
		replaceable, err := s.List(zoneName, ListOptions{BodyID: options.ReplaceID})
		if core.IsErr(err, "cannot list replaceable: %v", err) {
			s.store.Delete(bodyFile)
			return err
		}
		deletables = append(deletables, replaceable...)
	}

	header := Header{
		Name:        name,
		Author:      s.CurrentUser.ID(),
		Size:        hsr.bytesRead,
		Hash:        hash.Sum(nil),
		Zip:         options.Zip,
		Thumbnail:   options.Thumbnail,
		ContentType: options.ContentType,
		Tags:        options.Tags,
		ModTime:     now,
		Meta:        options.Meta,
		BodyID:      ID,
		BodyKey:     bodyKey,
		IV:          iv,
	}
	headers := []Header{header}

	data, err := marshalHeaders(headers, zone.KeyId, zone.KeyValue)
	if core.IsErr(err, "cannot encrypt header: %v", err) {
		s.store.Delete(bodyFile)
		return err
	}

	headerFile := path.Join(zonesDir, zoneName, sub, fmt.Sprintf("%d.h", ID))
	hr := core.NewBytesReader(data)
	err = s.store.Write(headerFile, hr, nil)
	if core.IsErr(err, "cannot write header: %v", err) {
		s.store.Delete(bodyFile)
		return err
	}

	for _, header := range deletables {
		deleteFile(s.Name, zoneName, s.store, header)
	}

	return nil
}

func formatYearMonthDay(t time.Time) string {
	year, month, day := t.Year(), t.Month(), t.Day()
	return fmt.Sprintf("%04d%02d%02d", year%10000, month, day)
}

func generateThumbnail(r io.ReadSeeker, maxWidth, maxHeight int) ([]byte, error) {
	_, err := r.Seek(0, io.SeekEnd)
	if !core.IsErr(err, "cannot seek to end of file: %v") {
		return nil, err
	}

	// Decode the image from the provided input
	img, err := imaging.Decode(r)
	if err != nil {
		return nil, fmt.Errorf("failed to decode image: %w", err)
	}
	_, err = r.Seek(0, io.SeekStart)
	if core.IsErr(err, "cannot seek to start of file: %v", err) {
		return nil, err
	}

	// Reduce quality or dimensions until the thumbnail size is within the limit
	quality := 100
	for {
		// Generate the thumbnail with the specified dimensions and quality
		thumb := imaging.Thumbnail(img, maxWidth, maxHeight, imaging.Lanczos)
		buffer := new(bytes.Buffer)

		// Encode the thumbnail with the current quality setting
		err = jpeg.Encode(buffer, thumb, &jpeg.Options{Quality: quality})
		if err != nil {
			return nil, fmt.Errorf("failed to encode thumbnail: %w", err)
		}

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

func deleteFile(safeName, zoneName string, store storage.Store, header Header) error {
	ymd := formatYearMonthDay(header.ModTime)
	fullName := path.Join(zonesDir, zoneName, ymd, fmt.Sprintf("%d.b", header.BodyID))
	err := store.Delete(fullName)
	if core.IsErr(err, "cannot delete file: %v", err) {
		return err
	}

	_, err = sql.Exec("SET_DELETED_FILE", sql.Args{
		"safe":   safeName,
		"zone":   zoneName,
		"name":   header.Name,
		"ymd":    ymd,
		"bodyId": header.BodyID,
	})
	if core.IsErr(err, "cannot set deleted file: %v", err) {
		return err
	}

	return nil
}
