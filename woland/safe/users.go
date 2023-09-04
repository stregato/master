package safe

import (
	"fmt"
	"time"

	"github.com/godruoyi/go-snowflake"

	"github.com/stregato/master/woland/core"
	"github.com/stregato/master/woland/security"
)

const (
	ErrZoneNotExist    = "zone '%s' does not exist"               // Returned when a zone does not exist
	ErrZoneNameTooLong = "zone name '%s' too long, max length 32" // Returned when a zone name is too long
	ErrZoneExist       = "zone '%s' already exists"               //
	ErrNoAuth          = "user '%s['%s']' has not authorization for box '%s'"
	ErrNotAdmin        = "user '%s' has not admin rights for safe '%s'"
)

type SetUsersOptions struct {
	ReplaceUsers bool
	AlignDelay   time.Duration
	SyncAlign    bool
}

// SetUsers sets some users with corresponding permissions for a zone.
func SetUsers(s *Safe, users Users, options SetUsersOptions) error {
	currentUserId := s.CurrentUser.Id
	if s.users[currentUserId]&PermissionAdmin == 0 {
		return fmt.Errorf(ErrNotAdmin, currentUserId, s.Name)
	}

	err := writePermissionChange(s.stores[0], s.Name, s.CurrentUser, users)
	if core.IsErr(err, nil, "cannot write permission change in %s: %v", s.Name) {
		return err
	}

	if options.ReplaceUsers {
		s.users = users
	} else {
		for userId, permission := range s.users {
			if _, ok := users[userId]; !ok {
				users[userId] = permission
			}
		}
	}

	keyId, key, keys, delta, err := readKeystores(s.stores[0], s.Name, s.CurrentUser, s.users)
	if core.IsErr(err, nil, "cannot read keystores in %s: %v", s.Name) {
		return err
	}
	var includesRevoke bool
	for _, permission := range delta {
		includesRevoke = includesRevoke || permission == PermissionNone
	}

	if includesRevoke {
		keyId = snowflake.ID()
		key = core.GenerateRandomBytes(KeySize)
		keys[keyId] = key

		err = writeKeyStore(s.stores[0], s.Name, s.CurrentUser, keyId, key, users)
		if core.IsErr(err, nil, "cannot write keystore in %s: %v", s.Name) {
			return err
		}
		s.keyId = keyId
		s.keys = keys

		var align = func() {
			time.Sleep(options.AlignDelay)
			err = alignKeysInDir(s, "")
			core.IsErr(err, nil, "cannot align keys in directory: %v", err)
		}
		if options.SyncAlign {
			go align()
		} else {
			align()
		}

	} else {
		err = writeKeyStore(s.stores[0], s.Name, s.CurrentUser, keyId, key, delta)
		if core.IsErr(err, nil, "cannot write keystore in %s: %v", s.Name) {
			return err
		}
	}
	s.users = users

	return nil
}

func GetUsers(s *Safe) (Users, error) {
	return s.users, nil
}

func GetIdentities(s *Safe) ([]security.Identity, error) {
	return s.identities, nil
}
