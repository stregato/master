package safe

import (
	"fmt"
	"os"
	"path"
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
	AlignDelay time.Duration `json:"alignDelay"`
	SyncAlign  bool          `json:"syncAlign"`
}

// SetUsers sets some users with corresponding permissions for a zone.
func SetUsers(s *Safe, users Users, options SetUsersOptions) error {
	currentUserId := s.CurrentUser.Id

	_, err := SyncUsers(s)
	if core.IsErr(err, nil, "cannot sync users in %s: %v", s.Name) {
		return err
	}
	if s.users[currentUserId]&Admin == 0 {
		// error if the current user is not admin
		return fmt.Errorf(ErrNotAdmin, currentUserId, s.Name)
	}

	delta := map[string]Permission{} // delta is the difference between the current users and the new users
	var includesRevoke bool          // includesRevoke is true if the new users include a revoke of a permission

	for userId, permission := range users {
		if p, ok := s.users[userId]; !ok || p != permission {
			delta[userId] = permission
			includesRevoke = includesRevoke || permission <= Blocked
			err = setUserInDB(s.Name, userId, permission)
			if core.IsErr(err, nil, "cannot set user in %s: %v", s.Name) {
				return err
			}
		}
	}

	err = writePermissionChange(s.stores[0], s.Name, s.CurrentUser, delta)
	if core.IsErr(err, nil, "cannot write permission change in %s: %v", s.Name) {
		return err
	}

	if includesRevoke {
		keystore := Keystore{
			LastKeyId: snowflake.ID(),
			Keys:      make(map[uint64][]byte),
		}
		keystore.Keys[keystore.LastKeyId] = core.GenerateRandomBytes(KeySize)
		err = writeKeyStoreFile(s.stores[0], s.Name, s.CurrentUser, keystore, users)
		if core.IsErr(err, nil, "cannot write keystore in %s: %v", s.Name) {
			return err
		}
		s.keystore.LastKeyId = keystore.LastKeyId
		s.keystore.Keys[keystore.LastKeyId] = keystore.Keys[keystore.LastKeyId]
		err = writeKeyStoreToDB(s.Name, s.keystore)
		if core.IsErr(err, nil, "cannot write keystore in DB for %s: %v", s.Name) {
			return err
		}

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
		err = writeKeyStoreFile(s.stores[0], s.Name, s.CurrentUser, s.keystore, delta)
		if core.IsErr(err, nil, "cannot write keystore in %s: %v", s.Name) {
			return err
		}
	}

	err = SetCached(s.Name, s.stores[0], "config/.access.touch", nil, s.CurrentUser.Id)
	if core.IsErr(err, nil, "cannot create touch file in %s: %v", s.Name) {
		return err
	}

	for userId, permission := range delta {
		s.users[userId] = permission
		deleteInitiateFile(s.Name, s.stores[0], userId)
	}

	return nil
}

func GetUsers(s *Safe) (Users, error) {
	return s.users, nil
}

func SyncUsers(s *Safe) (int, error) {
	core.Info("synchronizing users in %s", s.Name)
	s.usersLock.Lock()
	defer s.usersLock.Unlock()

	synced, err := GetCached(s.Name, s.stores[0], "config/.access.touch", nil, "")
	if core.IsErr(err, nil, "cannot sync touch file in %s: %v", s.Name) {
		return 0, err
	}
	if synced {
		core.Info("users in %s are up to date", s.Name)
		return 0, nil
	}

	var store = s.stores[0]
	identities, err := syncIdentities(store, s.Name, s.CurrentUser)
	if core.IsErr(err, nil, "cannot read identities in %s: %v", s.Name) {
		return 0, err
	}
	core.Info("found %d new identities in safe %s", len(identities), s.Name)

	users, count, err := syncUsers(s.Name, store, s.CurrentUser, s.CreatorId, s.users)
	if core.IsErr(err, nil, "cannot sync users in %s: %v", s.Name) {
		return 0, err
	}
	core.Info("synchronized %d users in %s", count, s.Name)

	keystore, _, err := syncKeystore(store, s.Name, s.CurrentUser, s.users)
	if core.IsErr(err, nil, "cannot sync keystore in %s: %v", s.Name) {
		return 0, err
	}

	s.users = users
	s.keystore = keystore
	s.Permission = users[s.CurrentUser.Id]
	return count, nil
}

func setUserInDB(safeName string, userId string, permission Permission) error {
	_, err := sql.Exec("SET_USER", sql.Args{
		"safe":       safeName,
		"id":         userId,
		"permission": permission,
	})
	if core.IsErr(err, nil, "cannot set user in %s: %v", safeName) {
		return err
	}
	return nil
}

func getUsersFromDB(safeName string) (Users, error) {
	rows, err := sql.Query("GET_USERS", sql.Args{"safe": safeName})
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
	rows.Close()
	core.Info("read %d users in %s", len(users), safeName)
	return users, nil
}

func syncUsers(safeName string, store storage.Store, currentUser security.Identity, creatorId string, users_ Users) (users Users, diff int, err error) {
	var count int

	// users_, err := getUsersFromDB(safeName)
	// if core.IsErr(err, nil, "cannot get users in %s: %v", safeName) {
	// 	return Users{}, 0, err
	// }
	// core.Info("found %d users in safe %s", len(users_), safeName)

	// var synced bool
	// if !force {
	// 	synced, err = GetCached(safeName, store, ".users.touch", nil, "")
	// 	if core.IsErr(err, nil, "cannot sync touch file in %s: %v", safeName) {
	// 		return Users{}, 0, err
	// 	}
	// 	if synced {
	// 		core.Info("synchronized %d users in %s", count, safeName)
	// 		return users_, count, nil
	// 	}
	// }

	users, _, err = readChangeLogs(safeName, store, currentUser, creatorId, "")
	if core.IsErr(err, nil, "cannot read change logs in %s: %v", safeName) {
		return Users{}, 0, err
	}
	core.Info("found %d users in changelogs of safe %s", len(users), safeName)

	for userId, permission := range users {
		if p, ok := users_[userId]; !ok || p != permission {
			err = setUserInDB(safeName, userId, permission)
			if core.IsErr(err, nil, "cannot set user in %s: %v", safeName) {
				return Users{}, 0, err
			}
			count++
			core.Info("update user '%s' with permission %d", userId, permission)
		}
	}

	core.Info("synchronized %d users in %s", count, safeName)
	return users, count, nil
}

func syncUserJob(s *Safe) {
	s.wg.Add(1)
	for {
		select {
		case <-s.quit:
			core.Info("quit sync user job for %s", s.Name)
			s.wg.Done()
			return
		case <-s.syncUsers.C:
			SyncUsers(s)
		}
	}
}

func syncIdentities(store storage.Store, name string, currentUser security.Identity) (new []security.Identity, err error) {

	new, err = readIdentities(store)
	if core.IsErr(err, nil, "cannot read identities in %s: %v", name) {
		return nil, err
	}
	_, err = store.Stat(path.Join(name, IdentitiesFolder, currentUser.Id))
	missingIdentity := os.IsNotExist(err)
	if missingIdentity {
		err = writeIdentity(store, currentUser)
		if core.IsErr(err, nil, "cannot write identity to store %s: %v", store) {
			return nil, err
		}
		new = append(new, currentUser.Public())
	}
	if core.IsErr(err, nil, "cannot stat current user identity in %s: %v", name) {
		return nil, err
	}

	var creatorId string
	if missingIdentity {
		creatorId = currentUser.Id
	}
	err = SetCached(name, store, "config/.access.touch", nil, creatorId)
	if core.IsErr(err, nil, "cannot write touch file in %s: %v", name) {
		return nil, err
	}

	return new, nil
}
