package safe

import (
	"compress/gzip"
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
	Progress    chan int64     `json:"progress"`    // Send progress updates to the channel
	FileId      uint64         `json:"fileId"`      // Get the file with the specified body ID
	NoCache     bool           `json:"noCache"`     // Do not cache the file
	CacheExpire time.Duration  `json:"cacheExpire"` // Cache expiration time
	Range       *storage.Range `json:"range"`       // Range of bytes to read
	Sync        bool           `json:"sync"`        // Sync the headers before reading the file
}

// Get reads a file from a bucket. The destination can be a filename (string) or an io.Writer. If the destination is nil, the file is not written but the header is returned.
func Get(s *Safe, bucket, name string, dest any, options GetOptions) (Header, error) {
	core.Info("Getting %s/%s", bucket, name)

	if options.Sync {
		_, err := SyncBucket(s, bucket, SyncOptions{}, nil)
		if core.IsErr(err, nil, "cannot sync headers: %v", err) {
			return Header{}, err
		}
	}

	var header, err = getLastHeader(s, bucket, name, options.FileId)
	if core.IsErr(err, nil, "cannot get header: %v", err) {
		return Header{}, err
	}
	core.Info("header for %s/%s found, fileId %d", bucket, name, header.FileId)

	header, err = decryptPrivateHeader(s.CurrentUser, header)
	if core.IsErr(err, nil, "cannot decrypt header: %v", err) {
		return Header{}, err
	}

	if dest == nil && options.NoCache {
		return header, nil
	}

	var destFile string
	var w io.Writer
	var ok bool
	if destFile, ok = dest.(string); ok {
		os.MkdirAll(filepath.Dir(destFile), 0755)
		f, err := os.Create(destFile)
		if core.IsErr(err, nil, "cannot create file: %v", err) {
			return Header{}, err
		}
		defer f.Close()
		w = f
	} else if dest != nil {
		w, ok = dest.(io.Writer)
		if !ok {
			return Header{}, fmt.Errorf("destination must be a file or io.Writer: found %v", dest)
		}
	}

	if w != nil {
		w, err = decryptWriter(w, header.BodyKey, header.IV)
		if core.IsErr(err, nil, "cannot create decrypting writer: %v", err) {
			return Header{}, err
		}
		if options.Progress != nil {
			w = progressWriter(w, options.Progress)
			core.Info("Progress writer created")
		}
	}

	if !options.NoCache && header.Cached != "" {
		err = copyFromCachedFile(header, w)
		if err == nil {
			return header, nil
		}
	}

	var cachedFile string
	if !options.NoCache || header.Zip {
		if currentCacheSize < 0 {
			currentCacheSize = getCurrentCacheSize()
		}
		name := filepath.Join(CacheFolder, fmt.Sprintf("%d.cache", header.FileId))
		f, err := os.Create(name)
		if core.IsErr(err, nil, "cannot create cache file: %v", err) {
			return Header{}, err
		}
		defer f.Close()
		if !options.NoCache {
			cachedFile = name
		}

		err = writeFile(s.store, s.Name, bucket, options, header, f)
		if core.IsErr(err, nil, "cannot write file: %v", err) {
			return Header{}, err
		}
		f.Seek(0, 0)

		if header.Zip {
			r, err := gzip.NewReader(f)
			if core.IsErr(err, nil, "cannot create gzip reader: %v", err) {
				return Header{}, err
			}
			defer r.Close()
			if w != nil {
				n, err := io.Copy(w, r)
				if core.IsErr(err, nil, "cannot copy file %f: %v", f, err) {
					return Header{}, err
				}
				core.Info("Copied %d bytes from %s", n, f.Name())
			}
		} else {
			if w != nil {
				n, err := io.Copy(w, f)
				if core.IsErr(err, nil, "cannot copy file %f: %v", f, err) {
					return Header{}, err
				}
				core.Info("Copied %d bytes from %s", n, f.Name())
			}
		}
	} else if w != nil {
		err = writeFile(s.store, s.Name, bucket, options, header, w)
		if core.IsErr(err, nil, "cannot write file: %v", err) {
			return Header{}, err
		}
	}

	if destFile != "" || cachedFile != "" {
		updateHeaderInDB(s.Name, bucket, header.FileId, func(h Header) Header {
			if cachedFile != "" {
				h.Cached = cachedFile

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
			if destFile != "" {
				if h.Downloads == nil {
					h.Downloads = make(map[string]time.Time)
				}
				h.Downloads[destFile] = core.Now()
				core.Info("Added download location for %s: %s", header.Name, destFile)
			}
			header = h
			return h
		})
	}

	return header, nil
}

func getLastHeader(s *Safe, bucket, name string, fileId uint64) (Header, error) {
	var data []byte
	err := sql.QueryRow("GET_LAST_HEADER", sql.Args{
		"safe":   s.Name,
		"bucket": bucket,
		"name":   name,
		"fileId": fileId,
	}, &data)
	if err == sql.ErrNoRows {
		core.Info("file %s/%s does not exist", bucket, name)
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
	core.Info("header for %s/%s found, fileId %d", bucket, name, header.FileId)
	return header, nil
}

func copyFromCachedFile(header Header, w io.Writer) error {
	core.Info("Using cached file %s", header.Cached)
	var r io.ReadCloser
	var err error

	r, err = os.Open(header.Cached)
	if core.IsErr(err, nil, "cannot open cached file: %v", err) {
		return err
	}
	if header.Zip {
		r, err = gzip.NewReader(r)
		if core.IsErr(err, nil, "cannot create gzip reader: %v", err) {
			return err
		}
	}
	defer r.Close()
	if w != nil {
		_, err = io.Copy(w, r)
		core.IsErr(err, nil, "cannot copy cached file: %v", err)
	}
	core.IsErr(err, nil, "Cannot open cached file: %v")
	return err
}

func writeFile(store storage.Store, safeName, bucket string, options GetOptions, header Header, w io.Writer) error {
	var err error

	dir := hashPath(bucket)
	fullname := path.Join(safeName, DataFolder, dir, BodyFolder, fmt.Sprintf("%d", header.FileId))

	err = store.Read(fullname, options.Range, w, nil)
	if core.IsErr(err, nil, "cannot read file: %v", err) {
		return err
	}
	core.Info("Read %s[%d] into %s", header.Name, header.FileId, fullname)
	return nil
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
		var bucket string
		var data []byte
		err := sql.QueryRow("GET_CACHE_EXPIRE", nil, &saveName, &bucket, &data)
		if core.IsErr(err, nil, "cannot query file: %v", err) {
			return
		}
		err = json.Unmarshal(data, &header)
		if core.IsErr(err, nil, "cannot unmarshal header: %v", err) {
			return
		}

		os.Remove(header.Cached)
		currentCacheSize -= header.Size
		err = updateHeaderInDB(saveName, bucket, header.FileId, func(h Header) Header {
			h.Cached = ""
			h.CachedExpires = time.Time{}
			return h
		})
		core.IsErr(err, nil, "cannot save header to DB: %v", err)
	}
}
