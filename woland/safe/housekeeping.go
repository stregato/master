package safe

import (
	"path"
	"time"

	"github.com/stregato/master/woland/core"
	"github.com/stregato/master/woland/storage"
)

var HousekeepingMaxDuration = time.Hour * 23

func alignKeysInDir(s *Safe, dir string) error {
	ls, err := s.stores[0].ReadDir(path.Join(DataFolder, dir), storage.Filter{Suffix: ".h"})
	if core.IsErr(err, nil, "cannot read directory '%s': %v", dir, err) {
		return err
	}

	var files []string
	var headers []Header
	for _, l := range ls {
		headers2, keyId, err := readHeaders(s.stores[0], s.Name, dir, l.Name(), s.keys)
		if core.IsErr(err, nil, "cannot read headers from '%s': %v", l.Name(), err) {
			continue
		}
		if keyId >= s.keyId {
			continue
		}

		headers = append(headers, headers2...)
		files = append(files, l.Name())
	}

	if len(files) > 1 {
		err = writeHeaders(s.stores[0], s.Name, dir, s.keyId, s.keys, headers)
		if !core.IsErr(err, nil, "cannot write headers: %v", err) {
			for _, f := range files {
				err = s.stores[0].Delete(path.Join(DataFolder, dir, f))
				core.IsErr(err, nil, "cannot remove file '%s': %v", f, err)
			}
		}
	}

	ls, err = s.stores[0].ReadDir(path.Join(DataFolder, dir), storage.Filter{OnlyFolders: true})
	if core.IsErr(err, nil, "cannot read directory '%s': %v", dir, err) {
		return err
	}
	for _, l := range ls {
		err = alignKeysInDir(s, path.Join(dir, l.Name()))
		if core.IsErr(err, nil, "cannot align keys in directory '%s': %v", l.Name(), err) {
			continue
		}
	}
	return nil
}
