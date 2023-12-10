package safe

import (
	"flag"
	"fmt"
	"os"
	"path/filepath"
	"testing"

	"github.com/stregato/master/woland/core"
	"github.com/stregato/master/woland/security"
	"github.com/stregato/master/woland/sql"
	"github.com/stregato/master/woland/storage"
)

var storeUrl string
var dbPath string
var Identity1, Identity2 security.Identity
var access1, access2 string
var testSafeName = "test-safe"
var testData = []byte("Hello, World!")
var testSetup bool

func InitTest() {
	if testSetup {
		return
	}

	var err error
	store := *flag.String("store", "local", "store url")
	urls := storage.LoadTestURLs("../../../credentials/urls.yaml")

	storeUrl = urls[store]
	if storeUrl == "" {
		panic("invalid store " + store)
	}

	db := *flag.String("db", "mem", "db type")
	switch db {
	case "mem":
		dbPath = ":memory:"
	case "file":
		dbPath = filepath.Join(os.TempDir(), "woland-test.db")
	default:
		panic("invalid db type " + db)
	}

	Identity1, _ = security.NewIdentity("identity1")
	Identity2, _ = security.NewIdentity("identity2")

	access1, err = EncodeAccess("", testSafeName, Identity1.Id, nil, storeUrl)
	if err != nil {
		panic(err)
	}

	access2, err = EncodeAccess(Identity2.Id, testSafeName, Identity1.Id, nil, storeUrl)
	if err != nil {
		panic(err)
	}

	os.RemoveAll("/tmp/.identities")
	testSetup = true
}

func StartTestDB(t *testing.T, dbPath string) {
	sql.DeleteDB(dbPath)

	t.Cleanup(func() { sql.CloseDB() })
	err := sql.OpenDB(dbPath)
	core.TestErr(t, err, "cannot open db: %v", err)
	fmt.Printf("Test DB: %s", dbPath)
}

const (
	TestMemStoreUrl   = "mem://0"
	TestLocalStoreUrl = "file:///tmp"
)

const TestSafeName = "test-safe"
