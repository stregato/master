package safe

import (
	"crypto/aes"
	"crypto/cipher"
	"crypto/rand"
	"encoding/binary"
	"encoding/json"
	"fmt"
	"io"
	"time"
)

var ErrInvalidHeaders = fmt.Errorf("headers are invalid")
var ErrNoEncryptionKey = fmt.Errorf("no encryption key")

type Header struct {
	Name          string               `json:"name"`
	Author        string               `json:"author"`
	Size          int64                `json:"size"`
	Hash          []byte               `json:"hash"`
	Zip           bool                 `json:"zip"`
	Tags          []string             `json:"tags"`
	Thumbnail     []byte               `json:"thumbnail"`
	ContentType   string               `json:"contentType"`
	ModTime       time.Time            `json:"modTime"`
	Meta          map[string]any       `json:"meta"`
	BodyID        uint64               `json:"bodyID"`
	BodyKey       []byte               `json:"bodyKey"`
	IV            []byte               `json:"iv"`
	Deleted       bool                 `json:"deleted"`
	Downloads     map[string]time.Time `json:"downloads"`
	Cached        string               `json:"cached"`
	CachedExpires time.Time            `json:"cachedExpires"`
}

func marshalHeaders(headers []Header, keyID uint64, keyValue []byte) ([]byte, error) {
	headersBytes, err := json.Marshal(headers)
	if err != nil {
		return nil, err
	}

	block, err := aes.NewCipher(keyValue)
	if err != nil {
		return nil, err
	}

	ciphertext := make([]byte, 8+aes.BlockSize+len(headersBytes)) // 8 bytes for the KeyID
	binary.BigEndian.PutUint64(ciphertext[:8], keyID)

	iv := ciphertext[8 : 8+aes.BlockSize]
	if _, err := io.ReadFull(rand.Reader, iv); err != nil {
		return nil, err
	}

	stream := cipher.NewCFBEncrypter(block, iv)
	stream.XORKeyStream(ciphertext[8+aes.BlockSize:], headersBytes)

	return ciphertext, nil
}

func unmarshalHeaders(ciphertext []byte, keys map[uint64][]byte) ([]Header, error) {
	var headers []Header

	if len(ciphertext) < 8 {
		return headers, ErrInvalidHeaders
	}

	keyID := binary.BigEndian.Uint64(ciphertext[:8])

	key := keys[keyID]
	if key == nil {
		return headers, ErrNoEncryptionKey
	}

	block, err := aes.NewCipher(key)
	if err != nil {
		return headers, err
	}

	iv := ciphertext[8 : 8+aes.BlockSize]
	stream := cipher.NewCFBDecrypter(block, iv)
	stream.XORKeyStream(ciphertext[8+aes.BlockSize:], ciphertext[8+aes.BlockSize:])

	err = json.Unmarshal(ciphertext[8+aes.BlockSize:], &headers)
	if err != nil {
		return headers, err
	}

	return headers, nil
}
