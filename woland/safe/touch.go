package safe

import (
	"encoding/json"
	"fmt"
	"os"

	"github.com/stregato/master/woland/core"
	"github.com/stregato/master/woland/sql"
	"github.com/stregato/master/woland/storage"
)

// GetCached returns the modification time of the guard file.
func GetCached(name string, store storage.Store, key string, data any) (synced bool, err error) {
	node := fmt.Sprintf("safe:cache:%s", name)

	_, modTime, d, ok := sql.GetConfig(node, key)
	if !ok {
		core.Info("touch %s in '%s' does not exist in db", key, name)
		return false, nil
	}
	fileInfo, err := store.Stat(key)
	if !os.IsNotExist(err) && core.IsErr(err, nil, "cannot check touch file: %v", err) {
		return false, err
	}
	if os.IsNotExist(err) {
		core.Info("touch %s in '%s' does not exist in store", key, name)
		return false, nil
	}

	touch := fileInfo.ModTime()
	var diff = touch.Unix() - modTime
	if diff > 1 {
		core.Info("touch %s in '%s' is %d seconds older", key, name, diff)
		return false, nil
	}

	if data != nil {
		_, isBytesSlide := data.(*[]byte)
		if isBytesSlide {
			*data.(*[]byte) = d
		} else {
			err = json.Unmarshal(d, data)
			if core.IsErr(err, nil, "cannot unmarshal touch info in db %s in %s: %v", key, name, err) {
				return false, err
			}
		}
	}

	core.Info("touch %s in '%s' up to date db %d = store %d [%v]", key, name, modTime, touch.Unix(), touch)
	return true, nil
}

func SetCached(name string, store storage.Store, key string, value any, invalidateStore bool) error {
	node := fmt.Sprintf("safe:cache:%s", name)

	var data []byte

	if value != nil {
		var ok bool
		data, ok = value.([]byte)
		if !ok {
			var err error
			data, err = json.Marshal(value)
			if core.IsErr(err, nil, "cannot marshal value %v: %v", value) {
				return err
			}
		}
	}

	stat, err := store.Stat(key)
	if !os.IsNotExist(err) && core.IsErr(err, nil, "cannot stat touch file %s in %s: %v", key, name, err) {
		return err
	}

	if os.IsNotExist(err) || invalidateStore {
		err = storage.WriteFile(store, key, []byte{})
		if core.IsErr(err, nil, "cannot write touch file %s in %s: %v", key, name, err) {
			return err
		}
		stat, err = store.Stat(key)
		if core.IsErr(err, nil, "cannot stat touch file %s in %s: %v", key, name, err) {
			return err
		}
		core.Info("touch %s in '%s' created", key, name)
	}

	err = sql.SetConfig(node, key, "", stat.ModTime().Unix(), data)
	core.IsErr(err, nil, "cannot set touch info in db %s in %s: %v", key, name, err)

	return err
}
