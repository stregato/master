package safe

import (
	"testing"
	"time"

	"github.com/stretchr/testify/assert"

	"github.com/stregato/master/massolit/core"
)

// Header and encryptionKeys are as before...

func TestEncryptAndDecryptHeader(t *testing.T) {
	originalHeader := File{
		Name:        "file",
		Size:        1024,
		Zip:         false,
		Preview:     []byte{0xFF, 0xD8, 0xFF}, // Some bytes
		ContentType: "image/jpeg",
		ModTime:     time.Now(),
		BodyKey:     []byte("some_key"),
	}

	keyId := uint64(1234567890)
	keyValue := core.GenerateRandomBytes(KeySize)
	ciphertext, err := marshalHeaders([]File{originalHeader}, keyId, keyValue)
	assert.NoError(t, err, "encryptHeader failed")

	decryptedHeaders, err := unmarshalHeaders(ciphertext, map[uint64][]byte{keyId: keyValue})
	assert.NoError(t, err, "decryptHeader failed")
	decryptedHeader := decryptedHeaders[0]

	assert.Equal(t, originalHeader.Name, decryptedHeader.Name, "Name does not match original")
	assert.Equal(t, originalHeader.Size, decryptedHeader.Size, "Size does not match original")
	assert.Equal(t, originalHeader.Zip, decryptedHeader.Zip, "Zip does not match original")
	assert.Equal(t, originalHeader.ContentType, decryptedHeader.ContentType, "ContentType does not match original")
	assert.Equal(t, originalHeader.BodyKey, decryptedHeader.BodyKey, "BodyKey does not match original")

	// Using InDelta to account for potential slight differences in time precision
	assert.InDelta(t, originalHeader.ModTime.Unix(), decryptedHeader.ModTime.Unix(), 1.0, "ModTime does not match original")

	// To ensure that the Thumbnail field was correctly encrypted and decrypted,
	// we can compare it byte-by-byte instead of converting to a string.
	assert.EqualValues(t, originalHeader.Preview, decryptedHeader.Preview, "Thumbnail does not match original")
}
