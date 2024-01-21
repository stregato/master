package safe

import (
	"strconv"
	"testing"
	"time"

	"github.com/stregato/master/woland/core"
)

func TestHousekeeping(t *testing.T) {
	InitTest()
	StartTestDB(t, dbPath)

	testStoreConfig.Quota = 1000
	s, err := Create(Identity1, testSafe, testStoreConfig, nil, CreateOptions{Wipe: true})
	core.Assert(t, err == nil, "Cannot create safe: %v", err)

	for i := 0; i < 128; i++ {
		r := core.NewBytesReader(testData)
		_, err = Put(s, "bucket", "file"+strconv.Itoa(i), r, PutOptions{}, nil)
		core.TestErr(t, err, "cannot put file: %v")
	}

	s.enforceQuota <- true
	time.Sleep(5 * time.Second)
	s.lastQuotaEnforcement = time.Time{}
	core.Assert(t, s.storeSizes[s.PrimaryStore.Url()] < testStoreConfig.Quota, "Expected primary store size to be less than quota")

	Close(s)
}
