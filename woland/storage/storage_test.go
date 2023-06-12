package storage

import (
	"bytes"
	"testing"

	"github.com/google/uuid"
	"github.com/stretchr/testify/assert"
)

func testCreateFile(t *testing.T, s Store) {
	name := uuid.New().String()
	r := bytes.NewReader(make([]byte, 1024))
	assert.NoErrorf(t, s.Write(name, r, nil), "cannot write file %s", name)
	assert.NoErrorf(t, s.Delete(name), "cannot delete file %s", name)
}

func TestCreateFile(t *testing.T) {
	fs, err := Open("sftp://sftp_user:11H^m63W5vAL@localhost/sftp_user")
	assert.NoErrorf(t, err, "Cannot load SFTP config: %v", err)
	testCreateFile(t, fs)

}

func TestWebdav(t *testing.T) {
	fs, err := Open("dav://localhost/f2")
	assert.NoErrorf(t, err, "Cannot load SFTP config: %v", err)
	testCreateFile(t, fs)

}
