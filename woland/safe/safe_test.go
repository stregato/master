package safe

import (
	"bytes"
	"testing"

	"github.com/stretchr/testify/assert"

	"github.com/stregato/master/massolit/core"
	"github.com/stregato/master/massolit/sql"
	"github.com/stregato/master/massolit/storage"
)

var dbPath = sql.TempDB

// var dbPath = sql.MemoryDBPath
var storeUrl = TestLocalStoreUrl // TestMemStoreUrl

func TestNewAccess(t *testing.T) {
	StartTestDB(t, dbPath)

	access, err := EncodeAccess(TestID, "test", TestID, nil, "sftp://blabla")
	assert.Nil(t, err)

	path, creatorId, _, _, err := DecodeAccess(TestIdentity, access)
	assert.Nil(t, err)
	assert.Equal(t, "test", path)
	core.Assert(t, creatorId == TestID, "Expected creatorId to be %s, got %s", TestID, creatorId)

}

func TestOpen(t *testing.T) {
	StartTestDB(t, dbPath)

	// Prepare the necessary test inputs
	//	access, err := EncodeToken(TestID, "test-save", nil, "mem://314") // Provide a mock access string
	//	access, err := EncodeToken(TestID, "test-save", nil, "sftp://sftp_user:11H%5Em63W5vAL@localhost/sftp_user") // Provide a mock access string
	access, err := EncodeAccess(TestID, "test-save", TestID, nil, "file://tmp") // Provide a mock access string
	core.TestErr(t, err, "cannot encode access token: %v")

	// Call the Open function
	p, err := Open(TestIdentity, access, OpenOptions{})
	core.TestErr(t, err, "cannot open portal: %v")

	p.Close()
}

func TestZoneLocal(t *testing.T) {
	testZone(t, sql.TempDB, TestLocalStoreUrl)
}

func TestS3(t *testing.T) {
	credentials := storage.LoadTestURLs("../../../credentials/urls.yaml")
	testZone(t, sql.TempDB, credentials["s3"])
}

func testZone(t *testing.T, dbPath string, storeUrl string) {
	StartTestDB(t, dbPath)
	portal := OpenTestPortal(t, storeUrl, true)

	zoneName := "toyroom"
	err := safe.CreateZone(zoneName, nil)
	assert.Nil(t, err)

	data := []byte("Hello, World!")
	r := core.NewBytesReader(data)

	header, err := safe.Put(zoneName, "file1", r, PutOptions{
		Tags:        []string{"tag1", "tag2"},
		ContentType: "text/plain",
	})
	core.TestErr(t, err, "cannot put file: %v")

	headers, err := safe.ListFiles(zoneName, ListOptions{})
	core.TestErr(t, err, "cannot list files: %v")
	core.Assert(t, len(headers) == 1, "Expected 1 file, got %d", len(headers))
	header = headers[0]
	if header.Name != "/file1" {
		t.Errorf("Expected file name to be 'file1', got '%s'", header.Name)
	}
	if header.Size != int64(len(data)) {
		t.Errorf("Expected file size to be %d, got %d", len(data), header.Size)
	}

	b := bytes.Buffer{}
	_, err = safe.Get(zoneName, "/file1", &b, GetOptions{})
	assert.NoError(t, err)
	assert.Equal(t, data, b.Bytes())

	headers, err = safe.ListFiles(zoneName, ListOptions{})
	core.TestErr(t, err, "cannot list files: %v")
	header = headers[0]
	if header.Cached == "" {
		t.Errorf("Expected cached to be set")
	}

	safe.Close()
}
