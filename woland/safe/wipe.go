package safe

import (
	"github.com/stregato/master/massolit/core"
	"github.com/stregato/master/massolit/security"
	"github.com/stregato/master/massolit/storage"
)

func WipePortal(currentUser security.Identity, token string) error {
	portalName, _, urls, err := DecodeAccess(currentUser, token)
	if core.IsErr(err, nil, "invalid access token 'account'") {
		return err
	}

	for _, url := range urls {
		s, err := storage.Open(url)
		if core.IsErr(err, nil, "cannot open store: %v", err) {
			return err
		}

		err = s.Delete(portalName)
		if core.IsErr(err, nil, "cannot delete portal '%s': %v", portalName, err) {
			return err
		}
	}

	return nil
}
