package safe

import (
	"path"
	"sort"
	"strconv"
	"time"

	"github.com/stregato/master/woland/core"
	"github.com/stregato/master/woland/sql"
	"github.com/stregato/master/woland/storage"
)

var HousekeepingMaxDuration = time.Hour * 23

type cleanupCandidates struct {
	name    string
	fileId  uint64
	size    int64
	modTime time.Time
}

func enforceQuota(s *Safe) {
	for _, store := range s.stores {
		for _, sc := range s.StoreConfigs {
			if sc.Url == store.Url() {
				limit := sc.Quota * 9 / 10
				size, err := enforceQuotaOnStore(s.Name, store, sc.Primary, limit)
				if !core.IsErr(err, nil, "cannot enforce quota on store %s: %v", store, err) {
					s.storeSizesLock.Lock()
					s.storeSizes[store.Url()] = size
					s.storeSizesLock.Unlock()
				}
				break
			}
		}
	}
}

func enforceQuotaOnStore(safeName string, store storage.Store, primary bool, limit int64) (size int64, err error) {
	var candidates []cleanupCandidates
	var dataFolder = path.Join(safeName, DataFolder)
	var totalSize int64

	ls, err := store.ReadDir(dataFolder, storage.Filter{OnlyFolders: true})
	if core.IsErr(err, nil, "cannot list files: %v", err) {
		return 0, err
	}

	for _, bucketDir := range ls {
		bucket := bucketDir.Name()
		bucketPath := path.Join(dataFolder, bucket, BodyFolder)
		ls, err := store.ReadDir(bucketPath, storage.Filter{})
		if core.IsErr(err, nil, "cannot list files: %v", err) {
			continue
		}

		for _, l := range ls {
			fileId, err := strconv.ParseInt(l.Name(), 10, 64)
			if core.IsErr(err, nil, "cannot parse fileId: %v", err) {
				continue
			}
			name := path.Join(bucketPath, l.Name())
			candidates = append(candidates, cleanupCandidates{
				name:    name,
				fileId:  uint64(fileId),
				size:    l.Size(),
				modTime: l.ModTime(),
			})
			totalSize += l.Size()
		}
	}

	sort.Slice(candidates, func(i, j int) bool {
		return candidates[i].modTime.Before(candidates[j].modTime)
	})
	for i := 0; totalSize > limit && i < len(candidates); i++ {
		oldest := candidates[i]
		err := store.Delete(oldest.name)
		if core.IsErr(err, nil, "cannot delete file %s: %v", oldest.name, err) {
			continue
		}
		core.Info("deleted %s from %s size %d", oldest.name, store, oldest.size)
		totalSize -= oldest.size

		if primary {
			_, err := sql.Exec("SET_DELETED_FILE", sql.Args{"safe": safeName, "fileId": oldest.fileId})
			if !core.IsErr(err, nil, "cannot set deleted file: %v", err) {
				core.Info("set header for %d deleted for %s", oldest.fileId, safeName)
			}
		}
	}
	core.Info("enforced quota on %s: %d bytes occupied", store, totalSize)
	return totalSize, nil
}
