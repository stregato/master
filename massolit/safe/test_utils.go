package safe

import (
	"fmt"
	"testing"

	"github.com/stregato/master/massolit/core"
	"github.com/stregato/master/massolit/security"
	"github.com/stregato/master/massolit/sql"
)

var TestIdentity security.Identity
var TestID string

func init() {
	var err error
	TestIdentity, err = security.NewIdentity("test")
	if core.IsErr(err, nil, "cannot create identity: %v", err) {
		panic(err)
	}
	TestID = TestIdentity.ID
}

func StartTestDB(t *testing.T, dbPath string) {
	sql.DeleteDB(dbPath)

	t.Cleanup(func() { sql.CloseDB() })
	err := sql.OpenDB(dbPath)
	core.TestErr(t, err, "cannot open db: %v", err)
	fmt.Printf("Test DB: %s", dbPath)
	err = security.SetIdentity(TestIdentity)
	core.TestErr(t, err, "cannot set identity: %v", err)
}

const (
	TestMemStoreUrl   = "mem://0"
	TestLocalStoreUrl = "file:///tmp"
)

const TestPortalName = "test"

func OpenTestPortal(t *testing.T, storeUrl string, deleteFirst bool) *Safe {
	//	access, err := EncodeToken(TestID, "test", nil, "mem://")
	access, err := EncodeAccess(TestID, TestPortalName, nil, storeUrl)
	core.TestErr(t, err, "cannot encode token: %v")

	if deleteFirst {
		err = WipePortal(TestIdentity, access)
		core.TestErr(t, err, "cannot wipe portal: %v")
	}

	portal, err := Open(TestIdentity, access, OpenOptions{})
	core.TestErr(t, err, "cannot open portal: %v")

	return portal
}
