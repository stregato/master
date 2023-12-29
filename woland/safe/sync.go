package safe

import (
	"fmt"
	"os"
	"path"
	"strconv"
	"sync"
	"time"

	"github.com/stregato/master/woland/core"
	"github.com/stregato/master/woland/security"
	"github.com/stregato/master/woland/storage"
)

type SyncOptions struct {
	Replicate bool `json:"replicate"`
}

func SyncBucket(s *Safe, bucket string, SyncOptions SyncOptions, async func(int, error)) (changes int, err error) {
	if async != nil {
		go func() {
			changes, err = SyncBucket(s, bucket, SyncOptions, nil)
			async(changes, err)
		}()
		return 0, nil
	}
	origin := s.primary
	changes, err = synchorizeFiles(s.CurrentUser, origin, s.Name, bucket, s.keystore.Keys,
		s.compactHeaders, &s.compactHeadersWg)
	if core.IsErr(err, nil, "cannot synchronize files: %v", err) {
		return 0, err
	}
	return changes, nil
}

func synchorizeFiles(currentUser security.Identity, store storage.Store, safeName, bucket string,
	keys map[uint64][]byte, compactHeader chan CompactHeader, compactHeadersWg *sync.WaitGroup) (newFiles int, err error) {
	var touch time.Time

	hashedBucket := hashPath(bucket)
	synced, err := GetCached(safeName, store, fmt.Sprintf("data/%s/.touch", hashedBucket), nil, "")
	if core.IsErr(err, nil, "cannot check sync file: %v") {
		return 0, err
	}
	if synced {
		core.Info("safe '%s' bucket %s is up to date: sync file is up to date", safeName, bucket)
		return 0, nil
	}

	ls, err := store.ReadDir(path.Join(safeName, DataFolder, hashedBucket, HeaderFolder), storage.Filter{})
	if os.IsNotExist(err) || core.IsErr(err, nil, "cannot read dir %s/%s: %v", store, hashedBucket, err) {
		return 0, err
	}

	headerFiles, err := getHeadersIdsWithCount(store, safeName, bucket)
	if core.IsErr(err, nil, "cannot get headers ids: %v", err) {
		return 0, err
	}

	count := 0
	for _, l := range ls {
		name := l.Name()
		headerFile, err := strconv.ParseUint(path.Base(name), 10, 64)
		if core.IsErr(err, nil, "cannot parse header id: %v", err) {
			continue
		}

		if l.Size() < int64(MaxHeaderFileSize) {
			count++
		}

		if _, found := headerFiles[headerFile]; found {
			// header already in DB
			continue
		}

		filepath := path.Join(safeName, DataFolder, hashedBucket, HeaderFolder, name)
		headersFile, err := readHeadersFile(store, safeName, filepath, keys)
		if core.IsErr(err, nil, "cannot read headers: %v", err) {
			continue
		}

		for _, header := range headersFile.Headers {
			header, err = decryptPrivateHeader(currentUser, header)
			if core.IsErr(err, nil, "cannot decrypt header: %v", err) {
				continue
			}

			core.Info("saving header %s", header.Name)
			newFiles++
			err = insertHeaderOrIgnoreToDB(safeName, bucket, headerFile, header)
			core.IsErr(err, nil, "cannot save header to DB: %v", err)
		}
	}
	err = SetCached(safeName, store, fmt.Sprintf("data/%s/.touch", hashedBucket), nil, "")
	if core.IsErr(err, nil, "cannot check touch file: %v", err) {
		return 0, err
	}
	core.Info("saved touch information: %v", touch)

	if count > MaxHeadersFiles {
		compactHeadersWg.Add(1)
		compactHeader <- CompactHeader{
			BucketDir: hashedBucket,
		}
	}

	return newFiles, nil
}
