package safe

import (
	"fmt"
	"os"
	"path"
	"strconv"
	"time"

	"github.com/stregato/master/woland/core"
	"github.com/stregato/master/woland/security"
	"github.com/stregato/master/woland/sql"
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

	changes, err = synchorizeFiles(s.CurrentUser, s.stores[0], s.Name, bucket, s.keys)
	if core.IsErr(err, nil, "cannot synchronize files: %v", err) {
		return 0, err
	}
	return changes, nil
}

func synchorizeFiles(currentUser security.Identity, store storage.Store, safeName, bucket string, keys map[uint64][]byte) (newFiles int, err error) {
	var touch time.Time

	dir := hashPath(bucket)
	touchConfigKey := fmt.Sprintf("%s//%s", safeName, bucket)
	_, modTime, _, ok := sql.GetConfig("SAFE_TOUCH", touchConfigKey)
	if ok {
		touch, err = GetTouch(store, DataFolder, dir, ".touch")
		if core.IsErr(err, nil, "cannot check touch file: %v", err) {
			return 0, err
		}
		var diff = touch.Unix() - modTime
		if diff < 2 {
			core.Info("safe '%s' is up to date: touch %v is %d seconds older", safeName, touch, diff)
			return 0, nil
		} else {
			core.Info("safe '%s' is outdated: touch %v is %d seconds older", safeName, touch, diff)
		}
	}

	ls, err := store.ReadDir(path.Join(DataFolder, dir, HeaderFolder), storage.Filter{})
	if os.IsNotExist(err) || core.IsErr(err, nil, "cannot read dir %s/%s: %v", store, dir, err) {
		return 0, err
	}

	headerIds, err := getHeadersIds(store, safeName, bucket)
	if core.IsErr(err, nil, "cannot get headers ids: %v", err) {
		return 0, err
	}

	for _, l := range ls {
		name := l.Name()
		headerId, err := strconv.ParseUint(path.Base(name), 10, 64)
		if core.IsErr(err, nil, "cannot parse header id: %v", err) {
			continue
		}

		var knownHeaderId bool
		for _, id := range headerIds {
			if id == headerId {
				knownHeaderId = true
				break
			}
		}
		if knownHeaderId {
			continue
		}

		filepath := path.Join(DataFolder, dir, HeaderFolder, name)
		headers, _, err := readHeaders(store, safeName, filepath, keys)
		if core.IsErr(err, nil, "cannot read headers: %v", err) {
			continue
		}

		for _, header := range headers {
			if header.PrivateId != "" {
				key, err := getDiffHillmanKey(currentUser, header)
				if core.IsErr(err, nil, "cannot get hillman key: %v", err) {
					continue
				}
				attributes, err := decryptHeaderAttributes(key, header.IV, header.EncryptedAttributes)
				if core.IsErr(err, nil, "cannot decrypt attributes: %v", err) {
					continue
				}
				header.Attributes = attributes
				header.EncryptedAttributes = nil
				header.BodyKey = key
			}

			core.Info("saving header %s", header.Name)
			newFiles++
			err = insertHeaderOrIgnoreToDB(safeName, bucket, headerId, header)
			core.IsErr(err, nil, "cannot save header to DB: %v", err)
		}
	}
	touch, err = SetTouch(store, DataFolder, dir, ".touch")
	if core.IsErr(err, nil, "cannot check touch file: %v", err) {
		return 0, err
	}

	err = sql.SetConfig("SAFE_TOUCH", touchConfigKey, "", touch.Unix(), nil)
	if core.IsErr(err, nil, "cannot set safe touch file: %v", err) {
		return 0, err
	}
	core.Info("saved touch information: %v", touch)

	return newFiles, nil
}

func getHeadersIds(store storage.Store, safeName, bucket string) (ids []uint64, err error) {
	r, err := sql.Query("GET_HEADERS_IDS", sql.Args{
		"safe":   safeName,
		"bucket": bucket,
	})
	if err != sql.ErrNoRows && core.IsErr(err, nil, "cannot get headers ids: %v", err) {
		return nil, err
	}

	for r.Next() {
		var id uint64
		if core.IsErr(r.Scan(&id), nil, "cannot scan id: %v", err) {
			continue
		}
		ids = append(ids, id)
	}
	return ids, nil
}
