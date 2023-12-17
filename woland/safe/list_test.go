package safe

import (
	"strconv"
	"testing"
	"time"

	"github.com/stregato/master/woland/core"
	"github.com/stregato/master/woland/sql"
)

func TestList(t *testing.T) {
	InitTest()

	StartTestDB(t, dbPath)
	defer sql.CloseDB()

	s, err := Create(Identity1, testSafe, testUrl, nil, CreateOptions{Wipe: true})
	core.Assert(t, err == nil, "Cannot create safe: %v", err)

	for i := 0; i < 10; i++ {
		var name string
		if i < 5 {
			name = "b" + strconv.Itoa(i)
		} else {
			name = "a" + strconv.Itoa(i)
		}

		r := core.NewBytesReader(testData)
		_, err = Put(s, "bucket", name, r, PutOptions{}, nil)
		core.TestErr(t, err, "cannot put file: %v")
		if i == 8 || i == 0 {
			// Wait a bit to make sure the modTime is different
			time.Sleep(time.Second)
		}
	}

	files, err := ListFiles(s, "bucket", ListOptions{OrderBy: "modTime"})
	core.TestErr(t, err, "cannot list files: %v")
	core.Assert(t, len(files) == 10, "Expected 10 files, got %d", len(files))
	core.Assert(t, files[0].Name == "b0", "Expected first file to be 'b0', got '%s'", files[0].Name)

	files, err = ListFiles(s, "bucket", ListOptions{OrderBy: "modTime", ReverseOrder: true})
	core.TestErr(t, err, "cannot list files: %v")
	core.Assert(t, len(files) == 10, "Expected 10 files, got %d", len(files))
	core.Assert(t, files[0].Name == "a9", "Expected first file to be 'a9', got '%s'", files[0].Name)

	files, err = ListFiles(s, "bucket", ListOptions{OrderBy: "name"})
	core.TestErr(t, err, "cannot list files: %v")
	core.Assert(t, len(files) == 10, "Expected 10 files, got %d", len(files))
	core.Assert(t, files[0].Name == "a5", "Expected first file to be 'a5', got '%s'", files[0].Name)

	r := core.NewBytesReader(testData)
	file, err := Put(s, "bucket", "dir0/file2", r, PutOptions{}, nil)
	core.TestErr(t, err, "cannot put file: %v")
	core.Assert(t, file.Name == "dir0/file2", "Expected file name to be 'file1', got '%s'", file.Name)

	dirs, err := ListDirs(s, "bucket", ListDirsOptions{})
	core.TestErr(t, err, "cannot list dirs: %v")
	core.Assert(t, len(dirs) == 1, "Expected 1 dir, got %d", len(dirs))

}
