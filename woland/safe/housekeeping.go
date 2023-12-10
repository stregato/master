package safe

import (
	"time"

	"github.com/stregato/master/woland/core"
	"github.com/stregato/master/woland/sql"
	"github.com/stregato/master/woland/storage"
)

var HousekeepingMaxDuration = time.Hour * 23

func getSafeSize(quotaGroup string) (int64, error) {
	var total int64
	err := sql.QueryRow("GET_SAFE_SIZE", sql.Args{"quotaGroup": quotaGroup}, &total)
	if core.IsErr(err, nil, "cannot get safe size: %v", err) {
		return 0, err
	}
	return total, nil
}

func applyQuota(limit float32, quotaGroup string, stores []storage.Store, size int64, quota int64, sync bool) {
	if quotaGroup != "" && quota > 0 && size > int64(float32(quota)*limit) {
		core.Info("Quota exceeded: %d/%d", size, quota)
		if sync {
			cleanupFilesOnQuotaExceedance(quotaGroup, stores, size, quota)
		} else {
			go cleanupFilesOnQuotaExceedance(quotaGroup, stores, size, quota)
		}
	}
}

func cleanupFilesOnQuotaExceedance(quotaGroup string, stores []storage.Store, size int64, quota int64) error {
	for quotaGroup != "" && quota > 0 && size > quota*9/10 {
		var safeName string
		var fileId uint64
		var dir string
		var sz int64
		err := sql.QueryRow("GET_OLDEST_FILE", sql.Args{"quotaGroup": quotaGroup}, &safeName, &fileId, &dir, &sz)
		if core.IsErr(err, nil, "cannot get oldest file: %v", err) {
			return err
		}

		hashedDir := hashPath(dir)
		err = deleteFile(stores, safeName, hashedDir, fileId)
		if err == nil {
			size -= sz
		}
	}

	return nil
}
