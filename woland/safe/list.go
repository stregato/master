package safe

import (
	"encoding/json"
	"fmt"
	"strings"
	"time"

	"github.com/stregato/master/woland/core"
	"github.com/stregato/master/woland/sql"
)

type ListOptions struct {
	Name            string    `json:"name"`            // Filter on the file name
	Dir             string    `json:"dir"`             // Filter on the directory
	NoSync          bool      `json:"noSync"`          // Skip syncing with the store
	Recursive       bool      `json:"recursive"`       // Recursively list files in subfolders
	Prefix          string    `json:"prefix"`          // Filter on the file prefix
	Suffix          string    `json:"suffix"`          // Filter on the file suffix
	ContentType     string    `json:"contentType"`     // Filter on the content type
	FileId          uint64    `json:"bodyId"`          // Filter on the body ID
	Tags            []string  `json:"tags"`            // Filter on the tags
	Before          time.Time `json:"before"`          // Filter on the modification time
	After           time.Time `json:"after"`           // Filter on the modification time
	KnownSince      time.Time `json:"knownSince"`      // Filter on the sync time
	OnlyChanges     bool      `json:"onlyChanges"`     // Only return files that have changed since the last sync
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

	now := core.Now()
	lastSync := s.lastBucketSync[bucket]
	if !listOptions.NoSync || (s.MinimalSyncTime > 0 && s.MinimalSyncTime < now.Sub(lastSync)) {
		_, err := SyncBucket(s, bucket, SyncOptions{}, nil)
		if core.IsErr(err, nil, "cannot sync files: %v", err) {
			return nil, err
		}
		s.lastBucketSync[bucket] = now
	}

	tags, err := getTagsArg(listOptions.Tags)
	if core.IsErr(err, nil, "cannot get tags arg: %v", err) {
		return nil, err
	}

	var key string
	switch listOptions.OrderBy {
	case "name", "":
		key = "GET_HEADER_BY_FILE_NAME"
	case "modTime":
		key = "GET_HEADER_BY_MODTIME"
	default:
		return nil, fmt.Errorf("invalid order by: %s", listOptions.OrderBy)
	}
	if listOptions.ReverseOrder {
		key += "_DESC"
	}
	knownSince := listOptions.KnownSince
	if listOptions.OnlyChanges {
		knownSince = lastSync
	}

	var depth int
	if listOptions.Name != "" {
		depth += strings.Count(listOptions.Name, "/")
	} else if listOptions.Dir != "" {
		depth = 1 + strings.Count(listOptions.Dir, "/")
	}

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
		"before":         listOptions.Before.UnixMilli(),
		"after":          listOptions.After.UnixMilli(),
		"syncAfter":      knownSince.UnixMilli(),
		"offset":         listOptions.Offset,
		"depth":          depth,
		"limit":          listOptions.Limit,
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
	rows.Close()

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
	rows.Close()
	return dirs, nil
}
