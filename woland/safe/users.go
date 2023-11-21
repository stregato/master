package safe

import (
	"fmt"
	"time"

	"github.com/godruoyi/go-snowflake"

	"github.com/stregato/master/woland/core"
	"github.com/stregato/master/woland/security"
	"github.com/stregato/master/woland/sql"
	"github.com/stregato/master/woland/storage"
)

const (
	ErrZoneNotExist    = "zone '%s' does not exist"               // Returned when a zone does not exist
	ErrZoneNameTooLong = "zone name '%s' too long, max length 32" // Returned when a zone name is too long
	ErrZoneExist       = "zone '%s' already exists"               //
	ErrNoAuth          = "user '%s['%s']' has not authorization for box '%s'"
	ErrNotAdmin        = "user '%s' has not admin rights for safe '%s'"
)

type SetUsersOptions struct {
	ReplaceUsers bool          `json:"replaceUsers"`
	AlignDelay   time.Duration `json:"alignDelay"`
	SyncAlign    bool          `json:"syncAlign"`
}

// SetUsers sets some users with corresponding permissions for a zone.
func SetUsers(s *Safe, users Users, options SetUsersOptions) error {
	currentUserId := s.CurrentUser.Id

	users_, err := GetUsers(s)
	if core.IsErr(err, nil, "cannot get users in %s: %v", s.Name) {
		return err
	}

	if users_[currentUserId]&PermissionAdmin == 0 {
		return fmt.Errorf(ErrNotAdmin, currentUserId, s.Name)
	}

	err = writePermissionChange(s.stores[0], s.Name, s.CurrentUser, users)
	if core.IsErr(err, nil, "cannot write permission change in %s: %v", s.Name) {
		return err
	}

	if !options.ReplaceUsers {
		for userId, permission := range users_ {
			if _, ok := users[userId]; !ok {
				users[userId] = permission
			}
		}
	}

	keyId, key, keys, delta, err := readKeystores(s.stores[0], s.Name, s.CurrentUser, users)
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
			err = alignKeysInSafe(s)
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

	SetTouch(s.stores[0], ConfigFolder, ".touch")
	_, err = SyncUsers(s)
	return err
}

func GetUsers(s *Safe) (Users, error) {
	return getSafeUsers(s.Name)
}

func SyncUsers(s *Safe) (int, error) {
	core.Info("synchronizing users in %s", s.Name)
	s.usersLock.Lock()
	defer s.usersLock.Unlock()
	users, count, err := syncUsers(s.stores[0], s.Name, s.CurrentUser, s.CreatorId)
	if core.IsErr(err, nil, "cannot sync users in %s: %v", s.Name) {
		return 0, err
	}
	s.users = users
	core.Info("synchronized %d users in %s", count, s.Name)
	return count, nil
}

func getSafeUsers(name string) (Users, error) {
	rows, err := sql.Query("GET_USERS", sql.Args{"safe": name})
	if core.IsErr(err, nil, "cannot query users: %v", err) {
		return nil, err
	}

	users := make(Users)
	for rows.Next() {
		var userId string
		var permission int
		if core.IsErr(rows.Scan(&userId, &permission), nil, "cannot scan user: %v", err) {
			continue
		}
		users[userId] = Permission(permission)
	}
	return users, nil
}

func syncUsers(store storage.Store, name string, currentUser security.Identity, creatorId string) (users Users, diff int, err error) {
	users_, err := getSafeUsers(name)
	if core.IsErr(err, nil, "cannot get users in %s: %v", name) {
		return Users{}, 0, err
	}

	var touch time.Time
	_, modTime, _, ok := sql.GetConfig("SAFE_TOUCH", name)
	if ok {
		touch, err = GetTouch(store, ConfigFolder, ".touch")
		if core.IsErr(err, nil, "cannot check touch file: %v", err) {
			return users, 0, err
		}
		var diff = touch.Unix() - modTime
		if diff < 2 {
			core.Info("users in '%s' are up to date: touch %v is %d seconds older", name, touch, diff)
			return users, 0, nil
		}
	}

	users, _, err = readChangeLogs(store, name, currentUser, creatorId, "")
	if core.IsErr(err, nil, "cannot read change logs in %s: %v", name) {
		return Users{}, 0, err
	}
	identities, err := syncIdentities(store, name, currentUser)
	if core.IsErr(err, nil, "cannot read identities in %s: %v", name) {
		return Users{}, 0, err
	}

	for _, identity := range identities {
		if _, ok := users[identity.Id]; !ok {
			users[identity.Id] = PermissionWait
			core.Info("identity '%s' is waiting for access", identity.Id)
		}
	}

	var count int
	for userId, permission := range users {
		if p, ok := users_[userId]; !ok || p != permission {
			sql.Exec("SET_USER", sql.Args{
				"safe":       name,
				"id":         userId,
				"permission": permission,
			})
			count++
			core.Info("update user '%s' with permission %d", userId, permission)
		}
	}

	for userId := range users_ {
		if _, ok := users[userId]; !ok {
			sql.Exec("SET_USER", sql.Args{
				"safe":       name,
				"id":         userId,
				"permission": PermissionNone,
			})
			count++
			core.Info("delete user '%s'", userId)
		}
	}

	sql.SetConfig("SAFE_TOUCH", name, "", touch.Unix(), nil)

	core.Info("synchronized %d users in %s", count, name)
	return users, count, nil
}
