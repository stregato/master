package safe

import (
	"encoding/json"
	"fmt"
	"io"
	"os"
	"path"
	"path/filepath"
	"time"

	"github.com/stregato/master/woland/core"
	"github.com/stregato/master/woland/sql"
	"github.com/stregato/master/woland/storage"
)

var ErrFileNotExist = fmt.Errorf("file does not exist") // Returned when a file does not exist
var MaxCacheSize = int64(128 * 1024 * 1024)             // Maximum size of the cache
var DelayForDestination = 100 * time.Millisecond        // Delay before checking if the file is downloaded to the specified destination
var currentCacheSize int64 = -1                         // Current size of the cache

type GetOptions struct {
	Destination string              `json:"destination"` // Track the file is downloaded to the specified destination. File must be closed within a second
	Async       func(Header, error) `json:"-"`           // When not nil, the download is asynchronous and the function is called when the download is complete or fails
	Progress    chan int64          `json:"progress"`    // Send progress updates to the channel
	FileId      uint64              `json:"fileId"`      // Get the file with the specified body ID
	NoCache     bool                `json:"noCache"`     // Do not cache the file
	CacheExpire time.Duration       `json:"cacheExpire"` // Cache expiration time
	Range       *storage.Range      `json:"range"`       // Range of bytes to read
}

func Get(s *Safe, name string, w io.Writer, options GetOptions) (Header, error) {
	var data []byte
	err := sql.QueryRow("GET_LAST_HEADER", sql.Args{
		"safe":   s.Name,
		"name":   name,
		"fileId": options.FileId,
	}, &data)
	if err == sql.ErrNoRows {
		return Header{}, ErrFileNotExist
	}
	if core.IsErr(err, nil, "cannot query file: %v", err) {
		return Header{}, err
	}

	var header Header
	err = json.Unmarshal(data, &header)
	if core.IsErr(err, nil, "cannot unmarshal header: %v", err) {
		return Header{}, err
	}

	w, err = decryptWriter(w, header.BodyKey, header.IV)
	if core.IsErr(err, nil, "cannot create decrypting writer: %v", err) {
		return Header{}, err
	}

	if options.Progress != nil {
		w = progressWriter(w, options.Progress)
		core.Info("Progress writer created")
	}
	if header.Attributes.Zip {
		w, err = gunzipStream(w)
		if core.IsErr(err, nil, "cannot decompress data: %v", err) {
			return Header{}, err
		}
		core.Info("Gzip stream created")
	}

	if header.Cached != "" {
		r, err := os.Open(header.Cached)
		if err == nil {
			defer r.Close()
			if w != nil {
				_, err = io.Copy(w, r)
				core.IsErr(err, nil, "cannot copy cached file: %v", err)
			}
			if err == nil {
				return header, nil
			}
		}
		core.Info("Cannot open cached file: %v", err)
	}

	var cacheFile *os.File
	if !options.NoCache {
		cacheFile, err = getCacheFile(header)
		if core.IsErr(err, nil, "cannot create cache file: %v", err) {
			return Header{}, err
		}
	}

	if options.Async != nil {
		go func() {
			header, err := writeFile(s.stores[0], s.Name, options, header, w, cacheFile)
			options.Async(header, err)
		}()
		return header, nil
	} else {
		return writeFile(s.stores[0], s.Name, options, header, w, cacheFile)
	}
}

func getCacheFile(header Header) (*os.File, error) {
	if currentCacheSize < 0 {
		currentCacheSize = getCurrentCacheSize()
	}

	cacheFilename := filepath.Join(CacheFolder, fmt.Sprintf("%d.cache", header.FileId))
	cacheFile, err := os.Create(cacheFilename)
	if core.IsErr(err, nil, "cannot create cache file: %v", err) {
		return nil, err
	}
	return cacheFile, nil
}

func writeFile(store storage.Store, safeName string, options GetOptions, header Header, w io.Writer, cacheFile *os.File) (Header, error) {
	var err error

	if w != nil {
		w = io.MultiWriter(w, cacheFile)
	} else if cacheFile != nil {
		w = cacheFile
	} else {
		return Header{}, nil
	}

	hashedDir := hashPath(getDir(header.Name))
	fullname := path.Join(DataFolder, hashedDir, fmt.Sprintf("%d.b", header.FileId))

	err = store.Read(fullname, options.Range, w, nil)
	if core.IsErr(err, nil, "cannot read file: %v", err) {
		return Header{}, err
	}

	if options.Destination != "" || cacheFile != nil {
		updateHeaderInDB(safeName, header.FileId, func(h Header) Header {
			if options.Destination != "" {
				if h.Downloads == nil {
					h.Downloads = make(map[string]time.Time)
				}
				h.Downloads[options.Destination] = core.Now()
				core.Info("Added download location for %s: %s", header.Name, options.Destination)
			}
			if cacheFile != nil {
				h.Cached = cacheFile.Name()
				if options.CacheExpire > 0 {
					h.CachedExpires = core.Now().Add(options.CacheExpire)
				} else {
					h.CachedExpires = core.Now().Add(30 * 24 * time.Hour)
				}
				core.Info("Added cache location for %s: %s", header.Name, h.Cached)
				currentCacheSize += header.Size
				if currentCacheSize > MaxCacheSize {
					go removeOldestCacheFiles()
				}
			}
			return h
		})
	}

	return header, nil
}

func getCurrentCacheSize() int64 {
	var cacheSize int64
	var cacheMap = make(map[string]time.Time)
	folderPath := CacheFolder

	_ = filepath.Walk(folderPath, func(path string, info os.FileInfo, err error) error {
		if err != nil {
			return err
		}

		if !info.IsDir() {
			cacheSize += info.Size()
			cacheMap[path] = info.ModTime()
		}

		return nil
	})

	return cacheSize
}

func removeOldestCacheFiles() {
	for currentCacheSize > MaxCacheSize*9/10 {
		var header Header
		var saveName string
		var data []byte
		err := sql.QueryRow("GET_CACHE_EXPIRE", nil, &saveName, &data)
		if core.IsErr(err, nil, "cannot query file: %v", err) {
			return
		}
		err = json.Unmarshal(data, &header)
		if core.IsErr(err, nil, "cannot unmarshal header: %v", err) {
			return
		}

		os.Remove(header.Cached)
		currentCacheSize -= header.Size
		err = updateHeaderInDB(saveName, header.FileId, func(h Header) Header {
			h.Cached = ""
			h.CachedExpires = time.Time{}
			return h
		})
		core.IsErr(err, nil, "cannot save header to DB: %v", err)
	}
}
