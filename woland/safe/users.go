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
	ReplaceUsers bool          `json:"replaceUsers"`
	AlignDelay   time.Duration `json:"alignDelay"`
	SyncAlign    bool          `json:"syncAlign"`
}

// SetUsers sets some users with corresponding permissions for a zone.
func SetUsers(s *Safe, users Users, options SetUsersOptions) error {
	currentUserId := s.CurrentUser.Id

	users_, _, err := syncUsers(s.Name, s.stores[0], s.CurrentUser, s.CreatorId, true)
	if core.IsErr(err, nil, "cannot sync users in %s: %v", s.Name) {
		return err
	}
	if users_[currentUserId]&PermissionAdmin == 0 {
		return fmt.Errorf(ErrNotAdmin, currentUserId, s.Name)
	}
	keystore, _, err := syncKeystore(s.stores[0], s.Name, s.CurrentUser, users)
	if core.IsErr(err, nil, "cannot read keystores in %s: %v", s.Name) {
		return err
	}
	s.keystore = keystore

	delta := map[string]Permission{}
	var includesRevoke bool

	for userId, permission := range users {
		if p, ok := users_[userId]; !ok || p != permission {
			delta[userId] = permission
			includesRevoke = includesRevoke || permission == PermissionNone
		}
	}
	for userId := range users_ {
		if p, ok := users[userId]; !ok {
			if options.ReplaceUsers {
				delta[userId] = PermissionNone
				includesRevoke = true
			} else {
				users[userId] = p
			}
		}
	}

	err = writePermissionChange(s.stores[0], s.Name, s.CurrentUser, delta)
	if core.IsErr(err, nil, "cannot write permission change in %s: %v", s.Name) {
		return err
	}

	if includesRevoke {
		keystore.LastKeyId = snowflake.ID()
		key := core.GenerateRandomBytes(KeySize)
		keystore.Keys[keystore.LastKeyId] = key
		err = writeKeyStoreFile(s.stores[0], s.Name, s.CurrentUser, keystore, users)
		if core.IsErr(err, nil, "cannot write keystore in %s: %v", s.Name) {
			return err
		}
		s.keystore = keystore

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
		err = writeKeyStoreFile(s.stores[0], s.Name, s.CurrentUser, keystore, delta)
		if core.IsErr(err, nil, "cannot write keystore in %s: %v", s.Name) {
			return err
		}
	}

	err = SetCached(s.Name, s.stores[0], ".users.touch", nil, true)
	if core.IsErr(err, nil, "cannot create touch file in %s: %v", s.Name) {
		return err
	}

	s.users = users
	return nil
}

func GetUsers(s *Safe) (Users, error) {
	return s.users, nil
}

func SyncUsers(s *Safe) (int, error) {
	core.Info("synchronizing users in %s", s.Name)
	s.usersLock.Lock()
	defer s.usersLock.Unlock()
	users, count, err := syncUsers(s.Name, s.stores[0], s.CurrentUser, s.CreatorId, false)
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
	rows.Close()
	core.Info("read %d users in %s", len(users), name)
	return users, nil
}

func syncUsers(safeName string, store storage.Store, currentUser security.Identity, creatorId string, force bool) (users Users, diff int, err error) {
	var count int

	identities, err := syncIdentities(store, safeName, currentUser)
	if core.IsErr(err, nil, "cannot read identities in %s: %v", safeName) {
		return Users{}, 0, err
	}
	count += len(identities)
	core.Info("found %d new identities in safe %s", len(identities), safeName)

	users_, err := getSafeUsers(safeName)
	if core.IsErr(err, nil, "cannot get users in %s: %v", safeName) {
		return Users{}, 0, err
	}
	core.Info("found %d users in safe %s", len(users_), safeName)

	var synced bool
	if !force {
		synced, err = GetCached(safeName, store, ".users.touch", nil)
		if core.IsErr(err, nil, "cannot sync touch file in %s: %v", safeName) {
			return Users{}, 0, err
		}
		if synced {
			core.Info("synchronized %d users in %s", count, safeName)
			return users_, count, nil
		}
	}

	users, _, err = readChangeLogs(store, safeName, currentUser, creatorId, "")
	if core.IsErr(err, nil, "cannot read change logs in %s: %v", safeName) {
		return Users{}, 0, err
	}
	core.Info("found %d users in changelogs of safe %s", len(users), safeName)

	for _, identity := range identities {
		if _, ok := users[identity.Id]; !ok {
			users[identity.Id] = PermissionWait
			core.Info("identity '%s' is waiting for access", identity.Id)
		}
	}

	for userId, permission := range users {
		if p, ok := users_[userId]; !ok || p != permission {
			sql.Exec("SET_USER", sql.Args{
				"safe":       safeName,
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
				"safe":       safeName,
				"id":         userId,
				"permission": PermissionNone,
			})
			count++
			core.Info("delete user '%s'", userId)
		}
	}

	err = SetCached(safeName, store, ".users.touch", nil, false)
	if core.IsErr(err, nil, "cannot create touch file in %s: %v", safeName) {
		return Users{}, 0, err
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

	synced, err := GetCached(name, store, ".identities.touch", nil)
	if core.IsErr(err, nil, "cannot sync touch file in %s: %v", name) {
		return nil, err
	}

	if !synced {
		if core.IsErr(err, nil, "cannot get users in %s: %v", name) {
			return nil, err
		}

		new, err = readIdentities(store)
		if core.IsErr(err, nil, "cannot read identities in %s: %v", name) {
			return nil, err
		}
	}
	_, err = store.Stat(path.Join(UsersFolder, currentUser.Id, UserFile))
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

	if missingIdentity || !synced {
		users, err := getSafeUsers(name)
		if core.IsErr(err, nil, "cannot get users in %s: %v", name) {
			return nil, err
		}
		for _, identity := range new {
			if _, ok := users[identity.Id]; !ok {
				core.Info("user %s not found in %s users, added it", identity.Id, name)
				_, err = sql.Exec("INSERT_USER", sql.Args{
					"safe":       name,
					"id":         identity.Id,
					"permission": PermissionWait,
				})
				if core.IsErr(err, nil, "cannot insert user %s in %s: %v", identity.Id, name) {
					return nil, err
				}
			}
		}

		err = SetCached(name, store, ".identities.touch", nil, missingIdentity)
		if core.IsErr(err, nil, "cannot write touch file in %s: %v", name) {
			return nil, err
		}
	}

	return new, nil
}
