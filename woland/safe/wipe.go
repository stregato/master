package safe

import (
	"github.com/stregato/master/woland/core"
	"github.com/stregato/master/woland/security"
	"github.com/stregato/master/woland/storage"
)

func Wipe(currentUser security.Identity, token string) error {
	name, _, _, urls, err := DecodeAccess(currentUser, token)
	if core.IsErr(err, nil, "invalid access token 'account'") {
		return err
	}

	for _, url := range urls {
		s, err := storage.Open(url)
		if core.IsErr(err, nil, "cannot open store: %v", err) {
			return err
		}

		err = s.Delete(name)
		if core.IsErr(err, nil, "cannot delete portal '%s': %v", name, err) {
			return err
		}
	}

	return nil
}
