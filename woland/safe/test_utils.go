package safe

import (
	"fmt"
	"testing"

	"github.com/stregato/master/woland/core"
	"github.com/stregato/master/woland/security"
	"github.com/stregato/master/woland/sql"
)

var TestIdentity = security.Identity{
	Id:      "A1fAUv0cNR7NOluPcw1FY4dvxkZUaPtcIRRNkhuRpgVsHkhHQnRSEIeawPakxP5NJwExc3lWDTT80gbnUkkJBZM=",
	Nick:    "test",
	Private: "0aTfmfyGzzJph5OjkOzn0303TvJt4kORWMrG6PAOkLI5M5gVa_U_t7mJ0L7u7VM8iG_3nGob0sQ_WAwsYoTysB5IR0J0UhCHmsD2pMT+TScBMXN5Vg00_NIG51JJCQWT",
	Email:   "test@woland.ch",
	ModTime: core.Now(),
}
var TestID = TestIdentity.Id

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

const TestSafeName = "test-safe"

func GetTestSafe(t *testing.T, storeUrl string, createFirst bool) *Safe {
	access, err := EncodeAccess(TestID, TestSafeName, TestID, nil, storeUrl)
	core.TestErr(t, err, "cannot encode token: %v")

	if createFirst {
		s, err := Create(TestIdentity, access, CreateOptions{Wipe: true})
		core.TestErr(t, err, "cannot wipe safe: %v")
		Close(s)
	}

	s, err := Open(TestIdentity, access, OpenOptions{})
	core.TestErr(t, err, "cannot open safe: %v")

	return s
}
