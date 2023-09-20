package safe

import (
	"fmt"
	"path"
	"time"

	"github.com/stregato/master/woland/core"
	"github.com/stregato/master/woland/sql"
	"github.com/stregato/master/woland/storage"
)

var HousekeepingMaxDuration = time.Hour * 23

func alignKeysInDir(s *Safe, dir string) error {
	ls, err := s.stores[0].ReadDir(path.Join(DataFolder, dir), storage.Filter{Suffix: ".h"})
	if core.IsErr(err, nil, "cannot read directory '%s': %v", dir, err) {
		return err
	}

	var files []string
	var headers []Header
	for _, l := range ls {
		headers2, keyId, err := readHeaders(s.stores[0], s.Name, dir, l.Name(), s.keys)
		if core.IsErr(err, nil, "cannot read headers from '%s': %v", l.Name(), err) {
			continue
		}
		if keyId >= s.keyId {
			continue
		}

		for _, h := range headers2 {
			if h.Size == 0 {
				headers = append(headers, h)
				files = append(files, l.Name())
				continue
			}

			hashedDir := hashPath(dir)
			fullname := path.Join(DataFolder, hashedDir, fmt.Sprintf("%d.b", h.FileId))
			_, err = s.stores[0].Stat(fullname)
			if err == nil {
				headers = append(headers, h)
				files = append(files, l.Name())
			}
		}

	}

	if len(files) > 1 {
		err = writeHeaders(s.stores[0], s.Name, dir, s.keyId, s.keys, headers)
		if !core.IsErr(err, nil, "cannot write headers: %v", err) {
			for _, f := range files {
				err = s.stores[0].Delete(path.Join(DataFolder, dir, f))
				core.IsErr(err, nil, "cannot remove file '%s': %v", f, err)
			}
		}
	}

	ls, err = s.stores[0].ReadDir(path.Join(DataFolder, dir), storage.Filter{OnlyFolders: true})
	if core.IsErr(err, nil, "cannot read directory '%s': %v", dir, err) {
		return err
	}
	for _, l := range ls {
		err = alignKeysInDir(s, path.Join(dir, l.Name()))
		if core.IsErr(err, nil, "cannot align keys in directory '%s': %v", l.Name(), err) {
			continue
		}
	}
	return nil
}

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
