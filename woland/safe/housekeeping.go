package safe

import (
	"time"
)

var HousekeepingMaxDuration = time.Hour * 23

// func housekeeping(portalName, zoneName string, stores []storage.Store, keyID uint64, keys map[uint64][]byte) error {
// 	dir := path.Join(zonesDir, zoneName)

// 	now := core.Now()
// 	modTime, err := GetTouch(store, path.Join(dir, ".housekeeping"))
// 	if core.IsErr(err, nil, "cannot check housekeeping file: %v", err) {
// 		return err
// 	}

// 	if now.Sub(modTime) > HousekeepingMaxDuration {
// 		return nil
// 	}

// 	return nil
// }
