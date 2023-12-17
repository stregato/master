package safe

import (
	"github.com/stregato/master/woland/core"
	"github.com/stregato/master/woland/security"
	"github.com/stregato/master/woland/storage"
)

func Wipe(currentUser security.Identity, name string) error {
	name, err := validName(name)
	if core.IsErr(err, nil, "invalid name %s: %v", name) {
		return err
	}

	_, url, err := getSafeFromDB(name)
	if core.IsErr(err, nil, "cannot get safe from DB for %s: %v", name) {
		return err
	}

	s, err := storage.Open(url)
	if core.IsErr(err, nil, "cannot open store: %v", err) {
		return err
	}

	err = s.Delete(name)
	if core.IsErr(err, nil, "cannot delete portal '%s': %v", name, err) {
		return err
	}

	return nil
}
