package safe

import (
	"encoding/json"
	"fmt"
	"os"
	"path"
	"strconv"
	"strings"
	"time"

	"github.com/stregato/master/woland/core"
	"github.com/stregato/master/woland/security"
	"github.com/stregato/master/woland/sql"
	"github.com/stregato/master/woland/storage"
)

type ListOptions struct {
	Name            string    `json:"name"`            // Filter on the file name
	Dir             string    `json:"dir"`             // Filter on the directory
	Prefix          string    `json:"prefix"`          // Filter on the file prefix
	Suffix          string    `json:"suffix"`          // Filter on the file suffix
	Depth           int       `json:"deep"`            // Filter on depth of the name when greater than 0
	ContentType     string    `json:"contentType"`     // Filter on the content type
	FileId          uint64    `json:"bodyId"`          // Filter on the body ID
	Tags            []string  `json:"tags"`            // Filter on the tags
	Before          time.Time `json:"before"`          // Filter on the modification time
	After           time.Time `json:"after"`           // Filter on the modification time
	KnownSince      time.Time `json:"knownSince"`      // Filter on the sync time
	Offset          int       `json:"offset"`          // Offset of the first file to return
	Limit           int       `json:"limit"`           // Maximum number of files to return
	IncludeDeleted  bool      `json:"includeDeleted"`  // Include deleted files
	Creator         string    `json:"creator"`         // Filter on the creator
	NoPrivate       bool      `json:"noPrivate"`       // Ignore private files
	PrivateId       string    `json:"privateId"`       // Filter on private files either created by the current user or the specified user
	Prefetch        bool      `json:"prefetch"`        // Prefetch the file bodies
	ErrorIfNotExist bool      `json:"errorIfNotExist"` // Return an error if the directory does not exist. Otherwise, return empty list
	OrderBy         string    `json:"orderBy"`         // Order by name or modTime. Default is name
	ReverseOrder    bool      `json:"reverseOrder"`    // Order descending when true. Default is false
}

func ListFiles(s *Safe, bucket string, listOptions ListOptions) ([]Header, error) {
	bucket = strings.Trim(bucket, "/")
	core.Info("list files '%s'", bucket)
	_, err := synchorizeFiles(s.CurrentUser, s.stores[0], s.Name, bucket, s.keys)
	if os.IsNotExist(err) && !listOptions.ErrorIfNotExist {
		return nil, nil
	}
	if core.IsErr(err, nil, "cannot sync safe '%s': %v", s.Name) {
		return nil, err
	}

	tags, err := getTagsArg(listOptions.Tags)
	if core.IsErr(err, nil, "cannot get tags arg: %v", err) {
		return nil, err
	}

	var key string
	switch listOptions.OrderBy {
	case "name", "":
		key = "GET_FILES_NAME"
	case "modTime":
		key = "GET_FILES_MODTIME"
	default:
		return nil, fmt.Errorf("invalid order by: %s", listOptions.OrderBy)
	}
	if listOptions.ReverseOrder {
		key += "_DESC"
	}

	var fromDepth int
	if listOptions.Dir != "" {
		fromDepth += 1 + strings.Count(listOptions.Dir, "/")
	}
	toDepth := fromDepth + listOptions.Depth

	args := sql.Args{
		"safe":           s.Name,
		"bucket":         bucket,
		"name":           listOptions.Name,
		"fileId":         listOptions.FileId,
		"dir":            listOptions.Dir,
		"prefix":         listOptions.Prefix,
		"suffix":         listOptions.Suffix,
		"contentType":    listOptions.ContentType,
		"creator":        listOptions.Creator,
		"noPrivate":      listOptions.NoPrivate,
		"privateId":      listOptions.PrivateId,
		"currentUser":    s.CurrentUser.Id,
		"tags":           tags,
		"includeDeleted": listOptions.IncludeDeleted,
		"before":         listOptions.Before.Unix(),
		"after":          listOptions.After.Unix(),
		"syncAfter":      listOptions.KnownSince.Unix(),
		"offset":         listOptions.Offset,
		"limit":          listOptions.Limit,
		"fromDepth":      fromDepth,
		"toDepth":        toDepth,
	}

	rows, err := sql.Query(key, args)
	if core.IsErr(err, nil, "cannot query files: %v", err) {
		return nil, err
	}

	var headers []Header
	for rows.Next() {
		var data []byte
		if core.IsErr(rows.Scan(&data), nil, "cannot scan file: %v", err) {
			continue
		}
		var header Header
		err = json.Unmarshal(data, &header)
		if core.IsErr(err, nil, "cannot unmarshal header: %v", err) {
			continue
		}
		headers = append(headers, header)
		core.Info("found header %s, %v, %d", header.Name, header.ModTime, header.FileId)
	}

	if listOptions.Prefetch {
		go func() {
			for _, header := range headers {
				if header.Cached != "" {
					continue
				}
				if header.Deleted {
					continue
				}
				if header.CachedExpires.Before(time.Now()) {
					continue
				}
				_, err := Get(s, bucket, header.Name, nil, GetOptions{FileId: header.FileId})
				core.IsErr(err, nil, "cannot prefetch file: %v", err)
			}
		}()
	}

	core.Info("found %d headers in %s/%s: key %s args %v", len(headers), s.Name, bucket, key, args)
	return headers, nil
}

type ListDirsOptions struct {
	Dir             string `json:"dir"`             // Filter on the directory
	Depth           int    `json:"depth"`           // Level of depth into subfolders
	ErrorIfNotExist bool   `json:"errorIfNotExist"` // Return an error if the directory does not exist. Otherwise, return empty list
}

func ListDirs(s *Safe, bucket string, listDirsOptions ListDirsOptions) ([]string, error) {
	listDirsOptions.Dir = strings.Trim(listDirsOptions.Dir, "/")
	core.Info("list dirs %s/%s", bucket, listDirsOptions.Dir)

	_, err := synchorizeFiles(s.CurrentUser, s.stores[0], s.Name, bucket, s.keys)
	if os.IsNotExist(err) && !listDirsOptions.ErrorIfNotExist {
		return nil, nil
	}
	if core.IsErr(err, nil, "cannot sync safe '%s': %v", s.Name) {
		return nil, err
	}

	fromDepth := 1
	if listDirsOptions.Dir != "" {
		fromDepth += 1 + strings.Count(listDirsOptions.Dir, "/")
	}
	toDepth := fromDepth + listDirsOptions.Depth

	rows, err := sql.Query("GET_FOLDERS", sql.Args{
		"safe":      s.Name,
		"bucket":    bucket,
		"dir":       listDirsOptions.Dir,
		"fromDepth": fromDepth,
		"toDepth":   toDepth,
	})
	if core.IsErr(err, nil, "cannot query folders: %v", err) {
		return nil, err
	}
	var dirs []string
	for rows.Next() {
		var d string
		if core.IsErr(rows.Scan(&d), nil, "cannot scan file: %v", err) {
			continue
		}
		dirs = append(dirs, d)
	}
	return dirs, nil
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
