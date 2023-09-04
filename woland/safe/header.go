package safe

import (
	"bytes"
	"crypto/aes"
	"crypto/cipher"
	"crypto/rand"
	"encoding/binary"
	"encoding/json"
	"fmt"
	"io"
	"path"
	"strings"
	"time"

	"github.com/godruoyi/go-snowflake"

	"github.com/stregato/master/woland/core"
	"github.com/stregato/master/woland/sql"
	"github.com/stregato/master/woland/storage"
)

var ErrInvalidHeaders = fmt.Errorf("headers are invalid")
var ErrNoEncryptionKey = fmt.Errorf("no encryption key")

type Header struct {
	Name          string               `json:"name"`
	Creator       string               `json:"creator"`
	Size          int64                `json:"size"`
	Hash          []byte               `json:"hash"`
	Zip           bool                 `json:"zip"`
	Tags          []string             `json:"tags"`
	Thumbnail     []byte               `json:"thumbnail"`
	ContentType   string               `json:"contentType"`
	ModTime       time.Time            `json:"modTime"`
	Meta          map[string]any       `json:"meta"`
	FileId        uint64               `json:"fileId"`
	BodyKey       []byte               `json:"bodyKey"`
	IV            []byte               `json:"iv"`
	Deleted       bool                 `json:"deleted"`
	Downloads     map[string]time.Time `json:"downloads"`
	Cached        string               `json:"cached"`
	CachedExpires time.Time            `json:"cachedExpires"`
}

func marshalHeaders(files []Header, keyId uint64, keyValue []byte) ([]byte, error) {

	data, err := json.Marshal(files)
	if core.IsErr(err, nil, "cannot marshal files: %v", err) {
		return nil, err
	}

	block, err := aes.NewCipher(keyValue)
	if err != nil {
		return nil, err
	}

	ciphertext := make([]byte, 8+aes.BlockSize+len(data)) // 8 bytes for the KeyID
	binary.BigEndian.PutUint64(ciphertext[:8], keyId)

	iv := ciphertext[8 : 8+aes.BlockSize]
	if _, err := io.ReadFull(rand.Reader, iv); err != nil {
		return nil, err
	}

	stream := cipher.NewCFBEncrypter(block, iv)
	stream.XORKeyStream(ciphertext[8+aes.BlockSize:], data)

	return ciphertext, nil
}

func unmarshalHeaders(ciphertext []byte, keys map[uint64][]byte) (headers []Header, keyId uint64, err error) {
	if len(ciphertext) < 8 {
		return headers, 0, ErrInvalidHeaders
	}

	keyId = binary.BigEndian.Uint64(ciphertext[:8])

	key := keys[keyId]
	if key == nil {
		return headers, 0, ErrNoEncryptionKey
	}

	block, err := aes.NewCipher(key)
	if err != nil {
		return headers, 0, err
	}

	iv := ciphertext[8 : 8+aes.BlockSize]
	stream := cipher.NewCFBDecrypter(block, iv)
	stream.XORKeyStream(ciphertext[8+aes.BlockSize:], ciphertext[8+aes.BlockSize:])

	err = json.Unmarshal(ciphertext[8+aes.BlockSize:], &headers)
	if err != nil {
		return headers, 0, err
	}

	return headers, keyId, nil
}

func writeHeaders(store storage.Store, safeName string, dir string, keyId uint64, keys Keys, headers []Header) error {
	data, err := marshalHeaders(headers, keyId, keys[keyId])
	if core.IsErr(err, nil, "cannot encrypt header: %v", err) {
		return nil
	}

	filePath := path.Join(DataFolder, dir, fmt.Sprintf("%d.h", snowflake.ID()))
	hr := core.NewBytesReader(data)
	err = store.Write(filePath, hr, nil)
	if core.IsErr(err, nil, "cannot write header: %v", err) {
		return err
	}
	core.Info("Wrote headers to %s/%s", store, filePath)
	return nil
}

func readHeaders(store storage.Store, safeName string, hashedDir, name string, keys Keys) (headers []Header, keyId uint64, err error) {
	var buf bytes.Buffer
	name = path.Join(DataFolder, hashedDir, name)
	err = store.Read(name, nil, &buf, nil)
	if core.IsErr(err, nil, "cannot read file %s/%s: %v", store, name, err) {
		return nil, 0, err
	}

	headers, keyId, err = unmarshalHeaders(buf.Bytes(), keys)
	if err == ErrNoEncryptionKey || core.IsErr(err, nil, "cannot unmarshal headers: %v", err) {
		return nil, 0, err
	}
	return headers, keyId, nil
}

func insertHeaderOrIgnoreToDB(safeName string, header Header) error {
	data, err := json.Marshal(header)
	if core.IsErr(err, nil, "cannot marshal header: %v", err) {
		return err
	}

	tags := strings.Join(header.Tags, " ") + " "
	r, err := sql.Exec("INSERT_HEADER", sql.Args{
		"safe":         safeName,
		"name":         header.Name,
		"fileId":       header.FileId,
		"base":         path.Base(header.Name),
		"dir":          getDir(header.Name),
		"depth":        strings.Count(header.Name, "/"),
		"modTime":      header.ModTime.Unix(),
		"tags":         tags,
		"contentType":  header.ContentType,
		"deleted":      header.Deleted,
		"cacheExpires": header.CachedExpires.Unix(),
		"header":       data,
	})
	if core.IsErr(err, nil, "cannot save header: %v", err) {
		return err
	}
	if count, _ := r.RowsAffected(); count == 0 {
		core.Info("Header %s already exists", header.Name)
		return nil
	}
	core.Info("Saved header %s", header.Name)

	return nil
}

func updateHeaderInDB(safeName string, fileId uint64, update func(Header) Header) error {
	var data []byte

	err := sql.QueryRow("GET_LAST_HEADER", sql.Args{"safe": safeName, "name": "",
		"fileId": fileId}, &data)
	if core.IsErr(err, nil, "cannot get header: %v", err) {
		return err
	}

	var header Header
	err = json.Unmarshal(data, &header)
	if core.IsErr(err, nil, "cannot unmarshal header: %v", err) {
		return err
	}

	header = update(header)
	data, err = json.Marshal(header)
	if core.IsErr(err, nil, "cannot marshal header: %v", err) {
		return err
	}

	_, err = sql.Exec("UPDATE_HEADER", sql.Args{"safe": safeName, "fileId": fileId,
		"cacheExpires": header.CachedExpires.Unix(), "header": data})
	if core.IsErr(err, nil, "cannot update header: %v", err) {
		return err
	}
	return nil
}
