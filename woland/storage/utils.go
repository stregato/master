package storage

import (
	"bytes"
	"encoding/json"
	"hash"
	"io"
	"os"

	"github.com/code-to-go/woland/core"
)

func ReadFile(s Store, name string) ([]byte, error) {
	var b bytes.Buffer
	err := s.Read(name, nil, &b, nil)
	return b.Bytes(), err
}

func WriteFile(s Store, name string, data []byte) error {
	b := core.NewBytesReader(data)
	defer b.Close()
	return s.Write(name, b, nil)
}

func ReadJSON(s Store, name string, v any, hash hash.Hash) error {
	data, err := ReadFile(s, name)
	if err == nil {
		if hash != nil {
			hash.Write(data)
		}

		err = json.Unmarshal(data, v)
	}
	return err
}

func WriteJSON(s Store, name string, v any, hash hash.Hash) error {
	b, err := json.Marshal(v)
	if err == nil {
		if hash != nil {
			hash.Write(b)
		}
		err = s.Write(name, core.NewBytesReader(b), nil)
	}
	return err
}

const maxSizeForMemoryCopy = 1024 * 1024

func CopyFile(dest Store, destName string, source Store, sourceName string) error {
	stat, err := source.Stat(sourceName)
	if core.IsErr(err, "cannot stat %s/%s: %v", source, sourceName) {
		return err
	}

	var r io.ReadSeeker
	if stat.Size() <= maxSizeForMemoryCopy {
		buf := bytes.Buffer{}
		err = source.Read(sourceName, nil, &buf, nil)
		if core.IsErr(err, "cannot read %s/%s: %v", source, sourceName) {
			return err
		}
		r = core.NewBytesReader(buf.Bytes())
	} else {
		file, err := os.CreateTemp("", "safepool")
		if core.IsErr(err, "cannot create temporary file for CopyFile: %v") {
			return err
		}

		err = source.Read(sourceName, nil, file, nil)
		if core.IsErr(err, "cannot read %s/%s: %v", source, sourceName) {
			return err
		}
		file.Seek(0, 0)
		r = file
		defer func() {
			file.Close()
			os.Remove(file.Name())
		}()
	}

	err = dest.Write(destName, r, nil)
	if core.IsErr(err, "cannot write %s/%s: %v", dest, destName) {
		return err
	}

	return nil
}
