package safe

import (
	"bytes"
	"os"
	"testing"

	"github.com/stretchr/testify/assert"

	"github.com/stregato/master/woland/core"
	"github.com/stregato/master/woland/security"
	"github.com/stregato/master/woland/sql"
	"github.com/stregato/master/woland/storage"
)

var dbPath = sql.TempDB

func TestNewAccess(t *testing.T) {
	StartTestDB(t, dbPath)

	access, err := EncodeAccess(TestID, "test", TestID, nil, "sftp://blabla")
	assert.Nil(t, err)

	path, creatorId, _, _, err := DecodeAccess(TestIdentity, access)
	assert.Nil(t, err)
	assert.Equal(t, "test", path)
	core.Assert(t, creatorId == TestID, "Expected creatorId to be %s, got %s", TestID, creatorId)

}

func TestCreate(t *testing.T) {
	StartTestDB(t, dbPath)

	access, err := EncodeAccess(TestID, "test-save", TestID, nil, "file:///tmp") // Provide a mock access string
	core.TestErr(t, err, "cannot encode access token: %v")

	// Call the Open function
	s, err := Create(TestIdentity, access, nil, CreateOptions{Wipe: true})
	core.TestErr(t, err, "cannot open portal: %v")

	Close(s)
}
func TestOpen(t *testing.T) {
	StartTestDB(t, dbPath)

	// Prepare the necessary test inputs
	//	access, err := EncodeToken(TestID, "test-save", nil, "mem://314") // Provide a mock access string
	//	access, err := EncodeToken(TestID, "test-save", nil, "sftp://sftp_user:11H%5Em63W5vAL@localhost/sftp_user") // Provide a mock access string
	access, err := EncodeAccess(TestID, "test-save", TestID, nil, "file:///tmp") // Provide a mock access string
	core.TestErr(t, err, "cannot encode access token: %v")

	// Call the Open function
	s, err := Open(TestIdentity, access, OpenOptions{})
	core.TestErr(t, err, "cannot open portal: %v")

	Close(s)
}

func TestZoneLocal(t *testing.T) {
	testSafe(t, sql.TempDB, TestLocalStoreUrl)
}

func TestS3(t *testing.T) {
	credentials := storage.LoadTestURLs("../../../credentials/urls.yaml")
	testSafe(t, sql.TempDB, credentials["s3"])
}

func testSafe(t *testing.T, dbPath string, storeUrl string) {
	StartTestDB(t, dbPath)
	s := GetTestSafe(t, storeUrl, true)

	data := []byte("Hello, World!")
	r := core.NewBytesReader(data)

	file, err := Put(s, "bucket", "file1", r, PutOptions{
		Tags:        []string{"tag1", "tag2"},
		ContentType: "text/plain",
	})
	core.TestErr(t, err, "cannot put file: %v")
	core.Assert(t, file.Name == "file1", "Expected file name to be 'file1', got '%s'", file.Name)

	r = core.NewBytesReader(data)
	file, err = Put(s, "bucket", "file2", r, PutOptions{
		Tags:        []string{"tag1", "tag2"},
		ContentType: "text/plain",
	})
	core.TestErr(t, err, "cannot put file: %v")
	core.Assert(t, file.Name == "file2", "Expected file name to be 'file1', got '%s'", file.Name)

	r = core.NewBytesReader(data)
	file, err = Put(s, "bucket", "file3", r, PutOptions{
		Tags:        []string{"tag1", "tag2"},
		ContentType: "text/plain",
	})
	core.TestErr(t, err, "cannot put file: %v")
	core.Assert(t, file.Name == "file3", "Expected file name to be 'file1', got '%s'", file.Name)

	SyncBucket(s, "bucket", SyncOptions{}, nil)
	files, err := ListFiles(s, "bucket", ListOptions{OrderBy: "modTime", ReverseOrder: true})
	core.TestErr(t, err, "cannot list files: %v")
	core.Assert(t, len(files) == 3, "Expected 1 file, got %d", len(files))
	file = files[0]
	if file.Name != "file3" {
		t.Errorf("Expected file name to be 'file1', got '%s'", file.Name)
	}
	if file.Size != int64(len(data)) {
		t.Errorf("Expected file size to be %d, got %d", len(data), file.Size)
	}

	b := bytes.Buffer{}
	_, err = Get(s, "bucket", "file1", &b, GetOptions{Destination: "bucket/file1"})
	core.TestErr(t, err, "cannot get file: %v")
	core.Assert(t, bytes.Equal(data, b.Bytes()), "Expected data to be '%s', got '%s'", data, b.Bytes())

	files, err = ListFiles(s, "bucket", ListOptions{OrderBy: "modTime"})
	core.TestErr(t, err, "cannot list files: %v")
	file = files[0]
	core.Assert(t, file.Cached != "", "Expected cached to be set")
	core.Assert(t, len(file.Downloads) == 1, "Expected 1 download, got %d", len(file.Downloads))

	r = core.NewBytesReader(data)
	file, err = Put(s, "bucket", "dir0/file2", r, PutOptions{
		Tags:        []string{"tag1", "tag2"},
		ContentType: "text/plain",
	})
	core.TestErr(t, err, "cannot put file: %v")
	core.Assert(t, file.Name == "dir0/file2", "Expected file name to be 'file1', got '%s'", file.Name)

	dirs, err := ListDirs(s, "bucket", ListDirsOptions{})
	core.TestErr(t, err, "cannot list dirs: %v")
	core.Assert(t, len(dirs) == 1, "Expected 1 dir, got %d", len(dirs))

	files, err = ListFiles(s, "bucket", ListOptions{})
	core.TestErr(t, err, "cannot list files: %v")
	file = files[0]
	core.Assert(t, file.Cached != "", "Expected cached to be set")
	core.Assert(t, len(file.Downloads) == 1, "Expected 1 download, got %d", len(file.Downloads))

	second, err := security.NewIdentity("test2")
	core.TestErr(t, err, "cannot create identity: %v")

	f, err := os.CreateTemp(os.TempDir(), "test-woland*")
	core.TestErr(t, err, "cannot create temp file: %v")
	defer os.Remove(f.Name())
	f.Write(data)
	h, err := Put(s, "bucket", "file1", f, PutOptions{
		Source:      f.Name(),
		Private:     second.Id,
		Tags:        []string{"tag1", "tag2"},
		ContentType: "text/plain",
	})
	f.Close()
	core.TestErr(t, err, "cannot put file: %v")
	core.Assert(t, !h.Downloads[f.Name()].IsZero(), "Expected download time to be set")

	err = SetUsers(s, map[string]Permission{second.Id: PermissionRead}, SetUsersOptions{})
	core.TestErr(t, err, "cannot set users: %v")

	users, err := GetUsers(s)
	core.TestErr(t, err, "cannot get users: %v")
	core.Assert(t, len(users) == 2, "Expected 2 users, got %d", len(users))

	Close(s)

	sql.CloseDB()
	StartTestDB(t, dbPath)

	access, err := EncodeAccess(second.Id, TestSafeName, TestID, nil, storeUrl)
	core.TestErr(t, err, "cannot encode token: %v")

	s, err = Open(second, access, OpenOptions{})
	core.TestErr(t, err, "cannot open safe: %v")

	files, err = ListFiles(s, "bucket", ListOptions{Name: "file1"})
	core.TestErr(t, err, "cannot list files: %v")
	core.Assert(t, len(files) == 2, "Expected 2 files, got %d", len(files))

	h, err = Get(s, "bucket", "file1", &b, GetOptions{FileId: h.FileId})
	core.TestErr(t, err, "cannot get file: %v")
	core.Assert(t, bytes.Equal(data, b.Bytes()), "Expected data to be '%s', got '%s'", data, b.Bytes())
	core.Assert(t, h.Attributes.ContentType == "text/plain", "Expected content type to be 'text/plain', got '%s'", h.Attributes.ContentType)
	core.Assert(t, len(h.Attributes.Tags) == 2, "Expected 2 tags, got %d", len(h.Attributes.Tags))

	Close(s)
}
