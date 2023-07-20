package safe

import (
	"os"
	"time"

	"github.com/stregato/masterwoland/core"
	"github.com/stregato/masterwoland/storage"
)

// GetTouch returns the modification time of the guard file.
func GetTouch(store storage.Store, filePath string) (time.Time, error) {
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
func SetTouch(store storage.Store, filePath string) error {
	emptyData := []byte{} // Empty data to write

	err := store.Write(filePath, core.NewBytesReader(emptyData), nil)
	if err != nil {
		return err
	}

	return nil
}
