package safe

import (
	"bytes"
	"os"
	"path"
	"testing"

	"github.com/stregato/master/woland/core"
	"github.com/stregato/master/woland/sql"
)

func TestPut(t *testing.T) {
	InitTest()
	StartTestDB(t, dbPath)
	defer sql.CloseDB()

	s, err := Create(Identity1, access1, nil, CreateOptions{Wipe: true})
	core.Assert(t, err == nil, "Cannot create safe: %v", err)

	r := core.NewBytesReader(testData)

	// Put with tags and zip compression
	file, err := Put(s, "bucket", "file1", r, PutOptions{
		Tags:        []string{"tag1", "tag2"},
		ContentType: "text/plain",
		Zip:         true,
	}, nil)
	core.TestErr(t, err, "cannot put file: %v")
	core.Assert(t, file.Name == "file1", "Expected file name to be 'file1', got '%s'", file.Name)
	core.Assert(t, len(file.Attributes.Tags) == 2, "Expected 2 tags, got %d", len(file.Attributes.Tags))
	core.Assert(t, file.Attributes.ContentType == "text/plain", "Expected content type to be 'text/plain', got '%s'", file.Attributes.ContentType)
	core.Assert(t, (file.Attributes.Tags[0] == "tag1" && file.Attributes.Tags[1] == "tag2") ||
		(file.Attributes.Tags[0] == "tag2" && file.Attributes.Tags[1] == "tag1"), "Expected tags to be 'tag1' and 'tag2', got '%s'")
	// Put with private access
	r = core.NewBytesReader(testData)
	file, err = Put(s, "bucket", "file2", r, PutOptions{
		Private:     Identity2.Id,
		ContentType: "text/plain",
	}, nil)
	core.TestErr(t, err, "cannot put file: %v")
	core.Assert(t, file.Name == "file2", "Expected file name to be 'file2', got '%s'", file.Name)
	core.Assert(t, file.Attributes.ContentType == "text/plain", "Expected content type to be 'text/plain', got '%s'", file.Attributes.ContentType)
	core.Assert(t, file.PrivateId == Identity2.Id, "Expected private to be '%s', got '%s'", Identity2.Id, file.PrivateId)

	dest := path.Join(os.TempDir(), "file1")
	_, err = Get(s, "bucket", "file1", dest, GetOptions{})
	content, _ := os.ReadFile(dest)
	core.TestErr(t, err, "cannot get file: %v")
	core.Assert(t, bytes.Equal(testData, content), "Expected data to be '%s', got '%s'", testData, content)
	core.Assert(t, !file.Uploading, "Expected file to be uploaded")

	dest = path.Join(os.TempDir(), "file2")
	h, err := Get(s, "bucket", "file2", dest, GetOptions{})
	content, _ = os.ReadFile(dest)
	core.TestErr(t, err, "cannot get file: %v")
	core.Assert(t, bytes.Equal(testData, content), "Expected data to be '%s', got '%s'", testData, content)
	core.Assert(t, !h.Downloads[dest].IsZero(), "Expected download time to be set")
	core.Assert(t, h.Cached != "", "Expected cached to be set")

	// Put async
	file, err = Put(s, "bucket", "file3", dest, PutOptions{
		Async: true,
	}, nil)
	core.TestErr(t, err, "cannot put file: %v")
	core.Assert(t, file.Name == "file3", "Expected file name to be 'file3', got '%s'", file.Name)
	core.Assert(t, file.Uploading, "Expected file to be uploading")

	Close(s)
}
