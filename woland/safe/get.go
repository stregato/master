package safe

import (
	"encoding/json"
	"fmt"
	"io"
	"os"
	"path"
	"path/filepath"
	"time"

	"github.com/stregato/master/massolit/core"
	"github.com/stregato/master/massolit/sql"
	"github.com/stregato/master/massolit/storage"
)

var ErrFileNotExist = fmt.Errorf("file does not exist") // Returned when a file does not exist
var MaxCacheSize = int64(128 * 1024 * 1024)             // Maximum size of the cache
var DelayForDestination = 100 * time.Millisecond        // Delay before checking if the file is downloaded to the specified destination
var currentCacheSize int64 = -1                         // Current size of the cache

type GetOptions struct {
	Destination string            // Track the file is downloaded to the specified destination. File must be closed within a second
	Async       func(File, error) // When not nil, the download is asynchronous and the function is called when the download is complete or fails
	Progress    chan int64        // Send progress updates to the channel
	BodyID      uint64            // Get the file with the specified body ID
	NoCache     bool              // Do not cache the file
	CacheExpire time.Duration     // Cache expiration time
	Range       *storage.Range    // Range of bytes to read
}

func (s *Safe) Get(zoneName, name string, w io.Writer, options GetOptions) (File, error) {
	_, ok := s.zones[zoneName]
	if !ok {
		return File{}, fmt.Errorf(ErrZoneNotExist, zoneName)
	}

	var data []byte
	err := sql.QueryRow("GET_LAST_FILE", sql.Args{
		"portal": s.Name,
		"zone":   zoneName,
		"name":   name,
		"bodyId": options.BodyID,
	}, &data)
	if err == sql.ErrNoRows {
		return File{}, ErrFileNotExist
	}
	if core.IsErr(err, nil, "cannot query file: %v", err) {
		return File{}, err
	}

	var header File
	err = json.Unmarshal(data, &header)
	if core.IsErr(err, nil, "cannot unmarshal header: %v", err) {
		return File{}, err
	}

	w, err = decryptWriter(w, header.BodyKey, header.IV)
	if core.IsErr(err, nil, "cannot create decrypting writer: %v", err) {
		return File{}, err
	}

	if options.Progress != nil {
		w = progressWriter(w, options.Progress)
	}
	if header.Zip {
		w, err = gunzipStream(w)
		if core.IsErr(err, nil, "cannot decompress data: %v", err) {
			return File{}, err
		}
	}

	if header.Cached != "" {
		r, err := os.Open(header.Cached)
		if err == nil {
			defer r.Close()
			if w != nil {
				_, err = io.Copy(w, r)
			}
			return File{}, err
		}
	}

	var cacheFile *os.File
	if !options.NoCache {
		cacheFile, err = getCacheFile(header)
		if core.IsErr(err, nil, "cannot create cache file: %v", err) {
			return File{}, err
		}
	}

	if options.Async != nil {
		go func() {
			header, err := writeFile(s.store, s.Name, zoneName, options, header, w, cacheFile)
			options.Async(header, err)
		}()
		return header, nil
	} else {
		return writeFile(s.store, s.Name, zoneName, options, header, w, cacheFile)
	}
}

func getCacheFile(header File) (*os.File, error) {
	if currentCacheSize < 0 {
		currentCacheSize = getCurrentCacheSize()
	}

	cacheFilename := filepath.Join(CacheFolder, fmt.Sprintf("%d.cache", header.BodyID))
	cacheFile, err := os.Create(cacheFilename)
	if core.IsErr(err, nil, "cannot create cache file: %v", err) {
		return nil, err
	}
	return cacheFile, nil
}

func writeFile(store storage.Store, portalName, zoneName string, options GetOptions, header File, w io.Writer, cacheFile *os.File) (File, error) {
	var err error

	if w != nil {
		w = io.MultiWriter(w, cacheFile)
	} else if cacheFile != nil {
		w = cacheFile
	} else {
		return File{}, nil
	}

	dir := path.Join(zonesDir, zoneName)
	ymd := formatYearMonthDay(header.ModTime)
	fullname := path.Join(dir, ymd, fmt.Sprintf("%d.b", header.BodyID))

	err = store.Read(fullname, options.Range, w, nil)
	if core.IsErr(err, nil, "cannot read file: %v", err) {
		return File{}, err
	}

	if cacheFile != nil {
		header.Cached = cacheFile.Name()
		cacheFile.Close()
		if options.CacheExpire > 0 {
			header.CachedExpires = core.Now().Add(options.CacheExpire)
		} else {
			header.CachedExpires = core.Now().Add(30 * 24 * time.Hour)
		}
		err := saveHeaderToDB(portalName, zoneName, ymd, header)
		core.IsErr(err, nil, "cannot save header to DB: %v", err)

		currentCacheSize += header.Size
		if currentCacheSize > MaxCacheSize {
			removeOldestCacheFiles()
		}
	}

	if options.Destination != "" {
		go func() {

			for i := 1; i < 11; i++ {
				time.Sleep(DelayForDestination * time.Duration(i))
				stat, err := os.Stat(options.Destination)
				if err == nil {
					if header.Downloads == nil {
						header.Downloads = make(map[string]time.Time)
					}
					header.Downloads[options.Destination] = stat.ModTime()
					err = saveHeaderToDB(portalName, zoneName, ymd, header)
					core.IsErr(err, nil, "cannot save header to DB: %v", err)
				}
			}
		}()
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
		var header File
		var saveName, zoneName string
		var data []byte
		err := sql.QueryRow("GET_OLDEST_CACHE_FILE", nil, &saveName, &zoneName, &data)
		if core.IsErr(err, nil, "cannot query file: %v", err) {
			return
		}
		err = json.Unmarshal(data, &header)
		if core.IsErr(err, nil, "cannot unmarshal header: %v", err) {
			return
		}

		os.Remove(header.Cached)
		currentCacheSize -= header.Size
		header.Cached = ""
		header.CachedExpires = time.Time{}
		ymd := formatYearMonthDay(header.ModTime)
		err = saveHeaderToDB(saveName, zoneName, ymd, header)
		core.IsErr(err, nil, "cannot save header to DB: %v", err)
	}
}
