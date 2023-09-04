package safe

import (
	"encoding/json"
	"os"
	"path"
	"strings"
	"time"

	"github.com/stregato/master/woland/core"
	"github.com/stregato/master/woland/sql"
	"github.com/stregato/master/woland/storage"
)

type ListOptions struct {
	Name            string    `json:"name"`            // Filter on the file name
	Depth           int       `json:"deep"`            // Level of depth into subfolders in the directory. -1 means infinite
	Suffix          string    `json:"suffix"`          // Filter on the file suffix
	ContentType     string    `json:"contentType"`     // Filter on the content type
	FileId          uint64    `json:"bodyId"`          // Filter on the body ID
	Tags            []string  `json:"tags"`            // Filter on the tags
	Before          time.Time `json:"before"`          // Filter on the modification time
	After           time.Time `json:"after"`           // Filter on the modification time
	Offset          int       `json:"offset"`          // Offset of the first file to return
	Limit           int       `json:"limit"`           // Maximum number of files to return
	IncludeDeleted  bool      `json:"includeDeleted"`  // Include deleted files
	Prefetch        bool      `json:"prefetch"`        // Prefetch the file bodies
	ErrorIfNotExist bool      `json:"errorIfNotExist"` // Return an error if the directory does not exist. Otherwise, return empty list
}

func ListFiles(s *Safe, dir string, listOptions ListOptions) ([]Header, error) {
	dir = strings.Trim(dir, "/")
	core.Info("list files '%s'", dir)
	err := synchorize(s.stores[0], s.Name, hashPath(dir), listOptions.Depth, s.keys)
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

	var fromDepth = strings.Count(dir, "/")
	var toDepth int
	if listOptions.Depth >= 0 {
		toDepth = fromDepth + listOptions.Depth
	}

	rows, err := sql.Query("GET_FILES", sql.Args{
		"safe":           s.Name,
		"name":           listOptions.Name,
		"fileId":         listOptions.FileId,
		"dir":            dir,
		"suffix":         listOptions.Suffix,
		"contentType":    listOptions.ContentType,
		"tags":           tags,
		"includeDeleted": listOptions.IncludeDeleted,
		"before":         listOptions.Before.Unix(),
		"after":          listOptions.After.Unix(),
		"offset":         listOptions.Offset,
		"limit":          listOptions.Limit,
		"fromDepth":      fromDepth,
		"toDepth":        toDepth,
	})
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
				_, err := Get(s, header.Name, nil, GetOptions{FileId: header.FileId})
				core.IsErr(err, nil, "cannot prefetch file: %v", err)
			}
		}()
	}

	return headers, nil
}

type ListDirsOptions struct {
	Depth           int  `json:"depth"`           // Level of depth into subfolders in the directory. -1 means infinite
	ErrorIfNotExist bool `json:"errorIfNotExist"` // Return an error if the directory does not exist. Otherwise, return empty list
}

func ListDirs(s *Safe, dir string, options ListDirsOptions) ([]string, error) {
	dir = strings.Trim(dir, "/")
	core.Info("list dir '%s'", dir)

	var depthPlusOne int
	if options.Depth >= 0 {
		depthPlusOne = options.Depth + 1
	}
	err := synchorize(s.stores[0], s.Name, hashPath(dir), depthPlusOne, s.keys)
	if os.IsNotExist(err) && !options.ErrorIfNotExist {
		return nil, nil
	}
	if core.IsErr(err, nil, "cannot sync safe '%s': %v", s.Name) {
		return nil, err
	}

	var fromDepth = strings.Count(dir, "/") + 1
	var toDepth int
	if options.Depth >= 0 {
		toDepth = fromDepth + options.Depth
	}

	rows, err := sql.Query("GET_FOLDERS", sql.Args{
		"safe":      s.Name,
		"dir":       dir,
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

func synchorize(store storage.Store, safeName, hashedDir string, depth int, keys map[uint64][]byte) error {
	var touch time.Time
	var err error

	_, i, _, ok := sql.GetConfig("SAFE_DIR_MODTIME", hashedDir)
	if ok {
		touch, err = GetTouch(store, hashedDir)
		if core.IsErr(err, nil, "cannot check touch file: %v", err) {
			return err
		}
		if time.Unix(i, 0) == touch {
			core.Info("safe '%s' is up to date", safeName)
			return nil
		}
	}

	ls, err := store.ReadDir(path.Join(DataFolder, hashedDir), storage.Filter{Suffix: ".h"})
	if core.IsErr(err, nil, "cannot read dir %s/%s: %v", store, hashedDir, err) {
		return err
	}

	s, _, _, _ := sql.GetConfig("SAFE_DIR_LAST", hashedDir)

	var last = s
	for _, l := range ls {
		if l.Name() <= s {
			continue
		}

		headers, _, err := readHeaders(store, safeName, hashedDir, l.Name(), keys)
		if err != nil {
			continue
		}
		if last == "" || last < l.Name() {
			last = l.Name()
		}

		for _, header := range headers {
			core.Info("saving header %s: %v", header.Name, header)
			err = insertHeaderOrIgnoreToDB(safeName, header)
			core.IsErr(err, nil, "cannot save header to DB: %v", err)
		}
	}
	err = sql.SetConfig("SAFE_DIR_LAST", hashedDir, last, 0, nil)
	if core.IsErr(err, nil, "cannot set safe touch file: %v", err) {
		return err
	}
	core.Info("saved last header %s", last)

	err = sql.SetConfig("SAFE_DIR_MODTIME", hashedDir, "", touch.Unix(), nil)
	if core.IsErr(err, nil, "cannot set zone touch: %v", err) {
		return err
	}

	if depth != 0 {
		ls, err := store.ReadDir(path.Join(DataFolder, hashedDir), storage.Filter{OnlyFolders: true})
		if core.IsErr(err, nil, "cannot read dir %s/%s: %v", store, hashedDir, err) {
			return err
		}

		for _, l := range ls {
			err = synchorize(store, safeName, path.Join(hashedDir, l.Name()), depth-1, keys)
			if core.IsErr(err, nil, "cannot sync dir %s/%s: %v", store, hashedDir, err) {
				return err
			}
		}
	}

	return nil
}
