package safe

import (
	"testing"

	"github.com/stregato/master/woland/core"
	"github.com/stregato/master/woland/sql"
	"github.com/stretchr/testify/assert"
)

func TestNewAccess(t *testing.T) {
	InitTest()

	StartTestDB(t, dbPath)

	access, err := EncodeAccess(Identity1.Id, "test", Identity1.Id, nil, "sftp://blabla")
	assert.Nil(t, err)

	path, creatorId, _, _, err := DecodeAccess(Identity1, access)
	assert.Nil(t, err)
	assert.Equal(t, "test", path)
	core.Assert(t, creatorId == Identity1.Id, "Expected creatorId to be %s, got %s", Identity1, creatorId)

}

func TestCreateAndOpen(t *testing.T) {
	InitTest()

	StartTestDB(t, dbPath)
	defer sql.CloseDB()

	// Call the Open function
	s, err := Create(Identity1, access1, nil, CreateOptions{Wipe: true})
	core.TestErr(t, err, "cannot open portal: %v")

	Close(s)
	s, err = Open(Identity1, access1, OpenOptions{})
	core.TestErr(t, err, "cannot open portal: %v")
	Close(s)
}
