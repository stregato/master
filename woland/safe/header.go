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
	Hash        []byte         `json:"ha,omitempty"` // Hash of the file
	ContentType string         `json:"co,omitempty"` // Content type of the file
	Thumbnail   []byte         `json:"th,omitempty"` // Thumbnail of the file
	Tags        []string       `json:"ta,omitempty"` // Tags of the file
	Extra       map[string]any `json:"ex,omitempty"` // Extra attributes of the file
}

type Header struct {
	Name                string               `json:"na"`            // Full path of the file
	Creator             string               `json:"cr"`            // Creator of the file
	Size                int64                `json:"si"`            //	Size of the file
	ModTime             time.Time            `json:"mo"`            // Last modification time of the file
	FileId              uint64               `json:"fi"`            // ID used in the storage to identify the file
	IV                  []byte               `json:"iv"`            // IV used to encrypt the attributes
	Zip                 bool                 `json:"zi,omitempty"`  // True if the file is zipped
	Attributes          Attributes           `json:"at,omitempty"`  // Attributes of the file
	EncryptedAttributes []byte               `json:"en,omitempty"`  // Encrypted attributes of the file
	BodyKey             []byte               `json:"bo,omitempty"`  // Key used to encrypt the body
	PrivateId           string               `json:"pr,omitempty"`  // ID of the user in case of private encryption
	Deleted             bool                 `json:"de,omitempty"`  // True if the file is deleted
	Cached              string               `json:"ca,omitempty"`  // Location where the file is cached
	CachedExpires       time.Time            `json:"cac,omitempty"` // Time when the cache expires
	Uploading           bool                 `json:"up,omitempty"`  // Number of uploads retries
	SourceFile          string               `json:"so,omitempty"`  // Source of the file
	HashedBucket        string               `json:"hb,omitempty"`  // Hashed bucket of the file
	ReplaceId           uint64               `json:"re,omitempty"`  // ID of the file to replace
	Replace             bool                 `json:"rp,omitempty"`  // True if the file is replacing another file
	Downloads           map[string]time.Time `json:"do,omitempty"`  // Map of download locations and times
}

func marshalHeaders(files []Header, keyId uint64, keyValue []byte) ([]byte, error) {

	data, err := json.Marshal(files)
	if core.IsErr(err, nil, "cannot marshal files: %v", err) {
		return nil, err
	}

	block, err := aes.NewCipher(keyValue)
	if core.IsErr(err, nil, "cannot create cipher: %v", err) {
		return nil, err
	}

	ciphertext := make([]byte, 8+aes.BlockSize+len(data)) // 8 bytes for the KeyID
	binary.BigEndian.PutUint64(ciphertext[:8], keyId)

	iv := ciphertext[8 : 8+aes.BlockSize]
	if _, err := io.ReadFull(rand.Reader, iv); err != nil {
		if core.IsErr(err, nil, "cannot read random bytes: %v", err) {
			return nil, err
		}
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

func writeHeaders(store storage.Store, safeName string, filePath string, keyId uint64, key []byte, headers []Header) error {
	data, err := marshalHeaders(headers, keyId, key)
	if core.IsErr(err, nil, "cannot encrypt header: %v", err) {
		return err
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
		"uploading":    header.Uploading,
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
		"uploading":    header.Uploading,
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
