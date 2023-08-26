package safe

import (
	"bytes"
	"encoding/json"
	"fmt"
	"path"
	"regexp"
	"strings"
	"time"

	"github.com/stregato/master/massolit/core"
	"github.com/stregato/master/massolit/sql"
	"github.com/stregato/master/massolit/storage"
)

var ErrInvalidTag = fmt.Errorf("invalid tag. Only alphanumeric characters are allowed")

type ListOptions struct {
	Folder         string    `json:"folder"`
	Name           string    `json:"name"`
	Suffix         string    `json:"suffix"`
	ContentType    string    `json:"contentType"`
	BodyID         uint64    `json:"bodyId"`
	Tags           []string  `json:"tags"`
	Before         time.Time `json:"before"`
	After          time.Time `json:"after"`
	Offset         int       `json:"offset"`
	Limit          int       `json:"limit"`
	IncludeDeleted bool      `json:"includeDeleted"`
	Prefetch       bool      `json:"prefetch"`
}

func (s *Safe) ListFiles(zoneName string, listOptions ListOptions) ([]File, error) {
	zone, ok := s.zones[zoneName]
	if !ok {
		return nil, fmt.Errorf(ErrZoneNotExist, zoneName)
	}
	err := sync(s.Name, zoneName, s.store, zone.Keys)
	if core.IsErr(err, nil, "cannot sync zone: %v", err) {
		return nil, err
	}

	tags, err := getTagsArg(listOptions.Tags)
	if core.IsErr(err, nil, "cannot get tags arg: %v", err) {
		return nil, err
	}

	if !strings.HasPrefix(listOptions.Folder, "/") {
		listOptions.Folder = "/" + listOptions.Folder
	}
	listOptions.Folder = path.Clean(listOptions.Folder)
	rows, err := sql.Query("GET_FILES", sql.Args{
		"portal":         s.Name,
		"zone":           zoneName,
		"name":           listOptions.Name,
		"bodyId":         listOptions.BodyID,
		"folder":         listOptions.Folder,
		"suffix":         listOptions.Suffix,
		"contentType":    listOptions.ContentType,
		"tags":           tags,
		"includeDeleted": listOptions.IncludeDeleted,
		"before":         listOptions.Before.Unix(),
		"after":          listOptions.After.Unix(),
		"offset":         listOptions.Offset,
		"limit":          listOptions.Limit,
	})
	if core.IsErr(err, nil, "cannot query files: %v", err) {
		return nil, err
	}

	var headers []File
	for rows.Next() {
		var data []byte
		if core.IsErr(rows.Scan(&data), nil, "cannot scan file: %v", err) {
			continue
		}
		var header File
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
				_, err := s.Get(zoneName, header.Name, nil, GetOptions{BodyID: header.BodyID})
				core.IsErr(err, nil, "cannot prefetch file: %v", err)
			}
		}()
	}

	return headers, nil
}

func (s *Safe) ListSubFolders(zoneName string, folder string) ([]string, error) {
	if !strings.HasPrefix(folder, "/") {
		folder = "/" + folder
	}
	folder = path.Clean(folder)

	rows, err := sql.Query("GET_FOLDERS", sql.Args{
		"portal": s.Name,
		"zone":   zoneName,
		"depth":  strings.Count(folder, "/") + 1,
		"folder": folder,
	})
	if core.IsErr(err, nil, "cannot query folders: %v", err) {
		return nil, err
	}
	var subFolders []string
	for rows.Next() {
		var subfolder string
		if core.IsErr(rows.Scan(&subfolder), nil, "cannot scan file: %v", err) {
			continue
		}
		subFolders = append(subFolders, subfolder)
	}
	return subFolders, nil
}

func getTagsArg(tags []string) (string, error) {
	arg := ""
	for _, tag := range tags {
		if !isAlphanumeric(tag) {
			return "", ErrInvalidTag
		}
		arg += tag + " %"
	}

	return arg, nil
}

func isAlphanumeric(s string) bool {
	match, _ := regexp.MatchString("^[a-zA-Z0-9]*$", s)
	return match
}

func sync(portalName, zoneName string, store storage.Store, keys map[uint64][]byte) error {
	var touch time.Time
	var err error

	dir := path.Join(zonesDir, zoneName)
	_, i, _, ok := sql.GetConfig("ZONE_TOUCH", dir)
	if ok {
		touch, err = GetTouch(store, dir)
		if core.IsErr(err, nil, "cannot check touch file: %v", err) {
			return err
		}
		if time.Unix(i, 0) == touch {
			return nil
		}
	}

	var lastYMD string
	err = sql.QueryRow("GET_LAST_YMD", sql.Args{"portal": portalName, "zone": zoneName}, &lastYMD)
	if err != sql.ErrNoRows && core.IsErr(err, nil, "cannot get last YMD: %v", err) {
		return err
	}
	ids, err := getBodyIds(portalName, zoneName, lastYMD)
	if core.IsErr(err, nil, "cannot get body ids: %v", err) {
		return err
	}

	ls, err := store.ReadDir(dir, storage.Filter{OnlyFolders: true})
	if core.IsErr(err, nil, "cannot read dir %s/%s: %v", store, dir, err) {
		return err
	}
	for _, l := range ls {
		ymd := l.Name()
		if !validYMD(ymd) || ymd < lastYMD {
			continue
		}

		ls2, err := store.ReadDir(path.Join(dir, ymd), storage.Filter{Suffix: ".h"})
		if core.IsErr(err, nil, "cannot read dir %s/%s: %v", store, dir, err) {
			continue
		}

		for _, l2 := range ls2 {
			var buf bytes.Buffer
			fullName := path.Join(dir, ymd, l2.Name())
			err = store.Read(fullName, nil, &buf, nil)
			if core.IsErr(err, nil, "cannot read file %s/%s: %v", store, fullName, err) {
				continue
			}

			headers, err := unmarshalHeaders(buf.Bytes(), keys)
			if err == ErrNoEncryptionKey {
				continue
			}
			if core.IsErr(err, nil, "cannot unmarshal headers: %v", err) {
				continue
			}

			for _, header := range headers {
				if ids[header.BodyID] {
					continue
				}
				err = saveHeaderToDB(portalName, zoneName, ymd, header)
				core.IsErr(err, nil, "cannot save header to DB: %v", err)
			}
		}
	}

	err = sql.SetConfig("ZONE_TOUCH", dir, "", touch.Unix(), nil)
	if core.IsErr(err, nil, "cannot set zone touch: %v", err) {
		return err
	}

	return nil
}

func saveHeaderToDB(portalName, zoneName, ymd string, header File) error {
	data, err := json.Marshal(header)
	if core.IsErr(err, nil, "cannot marshal header: %v", err) {
		return err
	}

	tags := strings.Join(header.Tags, " ") + " "
	_, err = sql.Exec("SET_FILE", sql.Args{
		"portal":       portalName,
		"zone":         zoneName,
		"name":         header.Name,
		"short":        path.Base(header.Name),
		"depth":        strings.Count(header.Name, "/"),
		"ymd":          ymd,
		"bodyId":       header.BodyID,
		"modTime":      header.ModTime.Unix(),
		"folder":       path.Dir(header.Name),
		"tags":         tags,
		"contentType":  header.ContentType,
		"deleted":      header.Deleted,
		"cacheExpires": header.CachedExpires.Unix(),
		"header":       data,
	})
	if core.IsErr(err, nil, "cannot save header: %v", err) {
		return err
	}

	return nil
}

func validYMD(value string) bool {
	match, _ := regexp.MatchString("^[0-9]{8}$", value)
	return match
}

func getBodyIds(portalName, zoneName, ymd string) (map[uint64]bool, error) {
	ids := map[uint64]bool{}
	rows, err := sql.Query("GET_FILE_BODY_ID", sql.Args{"portal": portalName, "zone": zoneName, "ymd": ymd})
	if core.IsErr(err, nil, "cannot get body ids: %v", err) {
		return nil, err
	}

	for rows.Next() {
		var id uint64
		if core.IsErr(rows.Scan(&id), nil, "cannot scan body id: %v", err) {
			continue
		}
		ids[id] = true
	}

	return ids, nil
}
