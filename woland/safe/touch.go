package safe

import (
	"os"
	"path"
	"time"

	"github.com/stregato/master/woland/core"
	"github.com/stregato/master/woland/storage"
)

// GetTouch returns the modification time of the guard file.
func GetTouch(store storage.Store, elem ...string) (time.Time, error) {
	filePath := path.Join(elem...)
	fileInfo, err := store.Stat(filePath)
	if os.IsNotExist(err) {
		return time.Time{}, nil
	}
	if err != nil {
		return time.Time{}, err
	}

	return fileInfo.ModTime(), nil
}

// SetTouch creates an empty file at the specified path using the provided Store implementation.
func SetTouch(store storage.Store, elem ...string) (time.Time, error) {
	emptyData := []byte{} // Empty data to write

	filePath := path.Join(elem...)
	err := store.Write(filePath, core.NewBytesReader(emptyData), nil)
	if err != nil {
		return time.Time{}, err
	}

	return GetTouch(store, filePath)

}
