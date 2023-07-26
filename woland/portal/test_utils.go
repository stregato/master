package portal

import (
	"testing"

	"github.com/stretchr/testify/assert"

	"github.com/stregato/master/woland/core"
	"github.com/stregato/master/woland/security"
	"github.com/stregato/master/woland/sql"
)

var TestIdentity security.Identity
var TestID string

func StartTestDB(t *testing.T) {
	TestIdentity, err := security.NewIdentity("test")
	if core.IsErr(err, "cannot create identity: %v", err) {
		panic(err)
	}
	TestID = TestIdentity.ID

	t.Cleanup(func() { sql.CloseDB() })
	err = sql.OpenDB(sql.MemoryDB)
	core.TestErr(t, err, "cannot open db: %v", err)
	err = security.SetIdentity(TestIdentity)
	core.TestErr(t, err, "cannot set identity: %v", err)
}

func OpenTestPortal(t *testing.T) *Portal {
	access, err := EncodeToken(TestID, "test", nil, "mem://")
	assert.Nil(t, err)

	portal, err := Open(TestIdentity, access, OpenOptions{})
	assert.Nil(t, err)

	return portal
}
