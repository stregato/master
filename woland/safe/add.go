package safe

import (
	"fmt"

	"github.com/stregato/master/woland/core"
)

func Add(name string, url string, creatorId string) error {
	name, err := validName(name)
	if core.IsErr(err, nil, "invalid name %s: %v", name) {
		return err
	}

	url_, creatorId_, err := getSafeFromDB(name)
	if err == nil && (url != url_ || creatorId != creatorId_) {
		return fmt.Errorf("safe already exist with different url or creatorId: name %s", name)
	}

	wipeSafeInDB(name)

	err = setSafeInDB(name, creatorId, url)
	if core.IsErr(err, nil, "cannot set safe in DB for %s: %v", name) {
		return err
	}
	return nil
}
