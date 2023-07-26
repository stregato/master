package portal

import (
	"bytes"
	"encoding/json"
	"fmt"
	"path"
	"regexp"
	"strings"
	"time"

	"github.com/stregato/master/woland/core"
	"github.com/stregato/master/woland/sql"
	"github.com/stregato/master/woland/storage"
)

var ErrInvalidTag = fmt.Errorf("invalid tag. Only alphanumeric characters are allowed")

type ListOptions struct {
	Folder         string
	Name           string
	Suffix         string
	ContentType    string
	BodyID         uint64
	Tags           []string
	Before         time.Time
	After          time.Time
	Offset         int
	Limit          int
	IncludeDeleted bool
	Prefetch       bool
}

func (s *Portal) List(zoneName string, listOptions ListOptions) ([]Header, error) {
	zone, ok := s.zones[zoneName]
	if !ok {
		return nil, ErrZoneNotExist
	}
	err := sync(s.Name, zoneName, s.store, zone.Keys)
	if core.IsErr(err, "cannot sync zone: %v", err) {
		return nil, err
	}

	tags, err := getTagsArg(listOptions.Tags)
	if core.IsErr(err, "cannot get tags arg: %v", err) {
		return nil, err
	}

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
	if core.IsErr(err, "cannot query files: %v", err) {
		return nil, err
	}

	var headers []Header
	for rows.Next() {
		var data []byte
		if core.IsErr(rows.Scan(&data), "cannot scan file: %v", err) {
			continue
		}
		var header Header
		err = json.Unmarshal(data, &header)
		if core.IsErr(err, "cannot unmarshal header: %v", err) {
			continue
		}
		headers = append(headers, header)
	}

	return headers, nil
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
		if core.IsErr(err, "cannot check touch file: %v", err) {
			return err
		}
		if time.Unix(i, 0) == touch {
			return nil
		}
	}

	var lastYMD string
	err = sql.QueryRow("GET_LAST_YMD", sql.Args{"portal": portalName, "zone": zoneName}, &lastYMD)
	if err != sql.ErrNoRows && core.IsErr(err, "cannot get last YMD: %v", err) {
		return err
	}
	ids, err := getBodyIds(portalName, zoneName, lastYMD)
	if core.IsErr(err, "cannot get body ids: %v", err) {
		return err
	}

	ls, err := store.ReadDir(dir, storage.Filter{OnlyFolders: true})
	if core.IsErr(err, "cannot read dir %s/%s: %v", store, dir, err) {
		return err
	}
	for _, l := range ls {
		ymd := l.Name()
		if !validYMD(ymd) || ymd < lastYMD {
			continue
		}

		ls2, err := store.ReadDir(path.Join(dir, ymd), storage.Filter{Suffix: ".h"})
		if core.IsErr(err, "cannot read dir %s/%s: %v", store, dir, err) {
			continue
		}

		for _, l2 := range ls2 {
			var buf bytes.Buffer
			fullName := path.Join(dir, ymd, l2.Name())
			err = store.Read(fullName, nil, &buf, nil)
			if core.IsErr(err, "cannot read file %s/%s: %v", store, fullName, err) {
				continue
			}

			headers, err := unmarshalHeaders(buf.Bytes(), keys)
			if err == ErrNoEncryptionKey {
				continue
			}
			if core.IsErr(err, "cannot unmarshal headers: %v", err) {
				continue
			}

			for _, header := range headers {
				if ids[header.BodyID] {
					continue
				}
				err = saveHeaderToDB(portalName, zoneName, ymd, header)
				core.IsErr(err, "cannot save header to DB: %v", err)
			}
		}
	}

	err = sql.SetConfig("ZONE_TOUCH", dir, "", touch.Unix(), nil)
	if core.IsErr(err, "cannot set zone touch: %v", err) {
		return err
	}

	return nil
}

func saveHeaderToDB(portalName, zoneName, ymd string, header Header) error {
	data, err := json.Marshal(header)
	if core.IsErr(err, "cannot marshal header: %v", err) {
		return err
	}

	tags := strings.Join(header.Tags, " ") + " "
	_, err = sql.Exec("SET_FILE", sql.Args{
		"portal":       portalName,
		"zone":         zoneName,
		"name":         header.Name,
		"ymd":          ymd,
		"bodyId":       header.BodyID,
		"modTime":      header.ModTime.Unix(),
		"folder":       getFolder(header.Name),
		"tags":         tags,
		"contentType":  header.ContentType,
		"deleted":      header.Deleted,
		"cacheExpires": header.CachedExpires.Unix(),
		"header":       data,
	})
	if core.IsErr(err, "cannot save header: %v", err) {
		return err
	}

	return nil
}

func getFolder(name string) string {
	// Use path.Dir to get the directory path
	folder := path.Dir(name)

	// Ensure the folder path starts with a '/'
	if !strings.HasPrefix(folder, "/") {
		folder = "/" + folder
	}

	return folder
}

func validYMD(value string) bool {
	match, _ := regexp.MatchString("^[0-9]{8}$", value)
	return match
}

func getBodyIds(portalName, zoneName, ymd string) (map[uint64]bool, error) {
	ids := map[uint64]bool{}
	rows, err := sql.Query("GET_FILE_BODY_ID", sql.Args{"portal": portalName, "zone": zoneName, "ymd": ymd})
	if core.IsErr(err, "cannot get body ids: %v", err) {
		return nil, err
	}

	for rows.Next() {
		var id uint64
		if core.IsErr(rows.Scan(&id), "cannot scan body id: %v", err) {
			continue
		}
		ids[id] = true
	}

	return ids, nil
}
