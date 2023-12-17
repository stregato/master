package safe

import (
	"testing"

	"github.com/stregato/master/woland/core"
	"github.com/stregato/master/woland/sql"
)

// func TestNewAccess(t *testing.T) {
// 	InitTest()

// 	StartTestDB(t, dbPath)

// 	access, err := EncodeAccess(Identity1.Id, "test", 123, Identity1.Id, "sftp://blabla")
// 	assert.Nil(t, err)

// 	name, id, creatorId, _, err := DecodeAccess(Identity1, access)
// 	assert.Nil(t, err)
// 	core.Assert(t, name == "test", "Expected name to be test, got %s", name)
// 	core.Assert(t, id == 123, "Expected id to be 123, got %d", id)
// 	core.Assert(t, creatorId == Identity1.Id, "Expected creatorId to be %s, got %s", Identity1, creatorId)

// }

func TestCreateAndOpen(t *testing.T) {
	InitTest()

	StartTestDB(t, dbPath)
	defer sql.CloseDB()

	// Call the Open function
	s, err := Create(Identity1, testSafe, testUrl, nil, CreateOptions{Wipe: true})
	core.TestErr(t, err, "cannot open portal: %v")

	Close(s)
	s, err = Open(Identity1, testSafe, OpenOptions{})
	core.TestErr(t, err, "cannot open portal: %v")
	Close(s)
}
