package safe

import (
	"fmt"
	"testing"

	"github.com/stregato/master/woland/core"
	"github.com/stregato/master/woland/security"
	"github.com/stregato/master/woland/sql"
)

var TestIdentity = security.Identity{
	Id:      "AoG3alCW3P1JQEnYFw+Z_24vqPNcC8_YVWarZKsodCIFQ+j_VmNa9gkWMJnpZe58zO1Rpx8U31q7n2XzAIn8jaQ@",
	Nick:    "test",
	Private: "4J9vYRT5EYeeNH_S9C0jY9eaxDGtheEk31tXwqCh22akyZIDXA9a_mbtqQ+5Qi3u_mJqpkndUmudPC4g6RCfNUPo_1ZjWvYJFjCZ6WXufMztUacfFN9au59l8wCJ_I2k",
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
