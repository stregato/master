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

var testUrl string
var dbPath string
var Identity1, Identity2 security.Identity
var testSafe = "test-safe"
var testData = []byte("Hello, World!")
var testSetup bool

func InitTest() {
	if testSetup {
		return
	}

	store := *flag.String("store", "local", "store url")
	urls := storage.LoadTestURLs("../../../credentials/urls.yaml")

	testUrl = urls[store]
	if testUrl == "" {
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
