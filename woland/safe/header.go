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

	"github.com/stregato/master/woland/core"
	"github.com/stregato/master/woland/security"
	"github.com/stregato/master/woland/sql"
	"github.com/stregato/master/woland/storage"
)

var ErrInvalidHeaders = fmt.Errorf("headers are invalid")
var ErrNoEncryptionKey = fmt.Errorf("no encryption key")

type Attributes struct {
	Hash        []byte         `json:"ha,omitempty"`
	ContentType string         `json:"co,omitempty"`
	Zip         bool           `json:"zi,omitempty"`
	Thumbnail   []byte         `json:"th,omitempty"`
	Tags        []string       `json:"ta,omitempty"`
	Extra       map[string]any `json:"ex,omitempty"`
}

type Header struct {
	Name                string               `json:"na"`
	Creator             string               `json:"cr"`
	Size                int64                `json:"si"`
	ModTime             time.Time            `json:"mo"`
	FileId              uint64               `json:"fi"`
	IV                  []byte               `json:"iv"`
	Attributes          Attributes           `json:"at,omitempty"`
	EncryptedAttributes []byte               `json:"en,omitempty"`
	BodyKey             []byte               `json:"bo,omitempty"`
	PrivateId           string               `json:"pr,omitempty"`
	Deleted             bool                 `json:"de,omitempty"`
	Downloads           map[string]time.Time `json:"do,omitempty"`
	Cached              string               `json:"ca,omitempty"`
	CachedExpires       time.Time            `json:"cac,omitempty"`
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

func writeHeaders(store storage.Store, safeName string, filePath string, keyId uint64, keys Keys, headers []Header) error {
	data, err := marshalHeaders(headers, keyId, keys[keyId])
	if core.IsErr(err, nil, "cannot encrypt header: %v", err) {
		return nil
	}

	hr := core.NewBytesReader(data)
	err = store.Write(filePath, hr, nil)
	if core.IsErr(err, nil, "cannot write header: %v", err) {
		return err
	}
	core.Info("Wrote headers to %s/%s", store, filePath)
	return nil
}

func readHeaders(store storage.Store, safeName string, filePath string, keys Keys) (headers []Header, keyId uint64, err error) {
	var buf bytes.Buffer
	err = store.Read(filePath, nil, &buf, nil)
	if core.IsErr(err, nil, "cannot read file %s/%s: %v", store, filePath, err) {
		return nil, 0, err
	}

	headers, keyId, err = unmarshalHeaders(buf.Bytes(), keys)
	if err == ErrNoEncryptionKey || core.IsErr(err, nil, "cannot unmarshal headers: %v", err) {
		return nil, 0, err
	}
	return headers, keyId, nil
}

func insertHeaderOrIgnoreToDB(safeName, bucket string, headerId uint64, header Header) error {
	data, err := json.Marshal(header)
	if core.IsErr(err, nil, "cannot marshal header: %v", err) {
		return err
	}

	header.Name = path.Clean(header.Name)
	depth := strings.Count(header.Name, "/")
	tags := strings.Join(header.Attributes.Tags, " ") + " "
	r, err := sql.Exec("INSERT_HEADER", sql.Args{
		"safe":         safeName,
		"bucket":       bucket,
		"name":         header.Name,
		"size":         header.Size,
		"fileId":       header.FileId,
		"headerId":     headerId,
		"base":         path.Base(header.Name),
		"dir":          getDir(header.Name),
		"depth":        depth,
		"modTime":      header.ModTime.Unix(),
		"syncTime":     time.Now().Unix(),
		"tags":         tags,
		"contentType":  header.Attributes.ContentType,
		"creator":      header.Creator,
		"privateId":    header.PrivateId,
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
	core.Info("Saved header %s [%d]", header.Name, header.FileId)

	return nil
}

func updateHeaderInDB(safeName, bucket string, fileId uint64, update func(Header) Header) error {
	var data []byte

	err := sql.QueryRow("GET_LAST_HEADER", sql.Args{
		"safe":   safeName,
		"bucket": bucket,
		"name":   "",
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

	_, err = sql.Exec("UPDATE_HEADER", sql.Args{
		"safe":         safeName,
		"bucket":       bucket,
		"fileId":       fileId,
		"cacheExpires": header.CachedExpires.Unix(),
		"header":       data})
	if core.IsErr(err, nil, "cannot update header: %v", err) {
		return err
	}
	return nil
}

func getDiffHillmanKey(currentUser security.Identity, header Header) ([]byte, error) {
	if header.PrivateId == currentUser.Id {
		secondaryKey, err := security.DiffieHellmanKey(currentUser, header.Creator)
		if core.IsErr(err, nil, "cannot create secondary key: %v", err) {
			return secondaryKey, err
		}
		return secondaryKey, nil
	} else if header.Creator == currentUser.Id {
		secondaryKey, err := security.DiffieHellmanKey(currentUser, header.PrivateId)
		if core.IsErr(err, nil, "cannot create secondary key: %v", err) {
			return secondaryKey, err
		}
		return secondaryKey, nil
	} else {
		return nil, ErrNoEncryptionKey
	}
}

func encryptHeaderAttributes(key []byte, iv []byte, attributes Attributes) ([]byte, error) {
	data, err := json.Marshal(attributes)
	if core.IsErr(err, nil, "cannot marshal attributes: %v", err) {
		return nil, err
	}
	encryptedAttributes, err := security.EncryptBlock(key, iv, data)
	if core.IsErr(err, nil, "cannot encrypt attributes: %v", err) {
		return nil, err
	}
	return encryptedAttributes, nil
}

func decryptHeaderAttributes(key []byte, iv []byte, encryptedAttributes []byte) (Attributes, error) {
	var attributes Attributes
	data, err := security.DecryptBlock(key, iv, encryptedAttributes)
	if core.IsErr(err, nil, "cannot decrypt attributes: %v", err) {
		return attributes, err
	}
	err = json.Unmarshal(data, &attributes)
	if core.IsErr(err, nil, "cannot unmarshal attributes: %v", err) {
		return attributes, err
	}
	return attributes, nil
}
