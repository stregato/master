package safe

import (
	"fmt"
	"sync"
	"time"

	"github.com/godruoyi/go-snowflake"

	"github.com/stregato/master/woland/core"
	"github.com/stregato/master/woland/security"
	"github.com/stregato/master/woland/sql"
	"github.com/stregato/master/woland/storage"
)

type CreateOptions struct {
	Wipe           bool          `json:"wipe"`           // Wipe is true if the safe should be wiped before creating it
	Description    string        `json:"description"`    // Description of the safe
	ChangeLogWatch time.Duration `json:"changeLogWatch"` // ChangeLogWatch is the period for watching changes in the change log
	ReplicaWatch   time.Duration `json:"replicaWatch"`   // ReplicaWatch is the period for synchronizing replicas
	Quota          int64         `json:"quota"`          // Quota is the maximum size of the safe in bytes
	QuotaGroup     string        `json:"quotaGroup"`     // QuotaGroup is the common prefix for the safes that share the quota
}

const (
	DefaultChangeLogWatch = time.Minute
	DefaultReplicaWatch   = 10 * time.Minute
)

func Create(currentUser security.Identity, access string, users Users, options CreateOptions) (*Safe, error) {
	name, id, creatorId, url, err := DecodeAccess(currentUser, access)
	if core.IsErr(err, nil, "invalid access token 'account'") {
		return nil, err
	}

	if creatorId != currentUser.Id {
		return nil, fmt.Errorf("invalid access token 'account'")
	}

	store, err := storage.Open(url)
	if core.IsErr(err, nil, "cannot connect to %s: %v", name) {
		return nil, err
	}

	if options.Wipe {
		_, err = sql.Exec("DELETE_SAFE_HEADERS", sql.Args{"safe": name})
		if core.IsErr(err, nil, "cannot wipe DB headers for safe %s: %v", name, err) {
			return nil, err
		}
		_, err = sql.Exec("DELETE_SAFE_USERS", sql.Args{"safe": name})
		if core.IsErr(err, nil, "cannot wipe DB users for safe %s: %v", name, err) {
			return nil, err
		}
		_, err = sql.Exec("DELETE_SAFE_CONFIGS", sql.Args{"safe": name})
		if core.IsErr(err, nil, "cannot wipe DB configs for safe %s: %v", name, err) {
			return nil, err
		}
		core.Info("wiped DB content for safe %s", name)
	}
	if options.Wipe {
		core.Info("wiping safe: name %s", name)
		store.Delete(name)
	} else {
		return nil, fmt.Errorf("safe already exist: name %s", name)
	}

	keystore := Keystore{
		LastKeyId: snowflake.ID(),
		Keys:      map[uint64][]byte{},
	}
	keystore.Keys[keystore.LastKeyId] = core.GenerateRandomBytes(KeySize)
	if users == nil {
		users = make(Users)
	}
	users[creatorId] = Reader + Standard + Admin + Creator

	if options.ChangeLogWatch == 0 {
		options.ChangeLogWatch = DefaultChangeLogWatch
	}
	if options.ReplicaWatch == 0 {
		options.ReplicaWatch = DefaultReplicaWatch
	}

	err = writeManifestFile(name, store, currentUser, manifestFile{
		CreatorId:      creatorId,
		Description:    options.Description,
		ChangeLogWatch: options.ChangeLogWatch,
		ReplicaWatch:   options.ReplicaWatch,
		Quota:          options.Quota,
		QuotaGroup:     options.QuotaGroup,
	})
	if core.IsErr(err, nil, "cannot write manifest file in %s: %v", name) {
		return nil, err
	}

	err = writePermissionChange(store, name, currentUser, users)
	if core.IsErr(err, nil, "cannot write permission change in %s: %v", name) {
		return nil, err
	}
	setUserInDB(name, currentUser.Id, Reader|Standard|Admin|Creator)

	err = writeKeyStoreToDB(name, keystore)
	if core.IsErr(err, nil, "cannot write keystore in DB for %s: %v", name) {
		return nil, err
	}
	err = writeKeyStoreFile(store, name, currentUser, keystore, users)
	if core.IsErr(err, nil, "cannot write keystore in %s: %v", name) {
		return nil, err
	}

	_, err = syncIdentities(store, name, currentUser)
	if core.IsErr(err, nil, "cannot sync identities in %s: %v", name) {
		return nil, err
	}

	err = SetCached(name, store, "config/.access.touch", nil, currentUser.Id)
	if core.IsErr(err, nil, "cannot create touch file in %s: %v", name) {
		return nil, err
	}

	core.Info("safe created: name %s, creator %s, description %s, quota %d", name, currentUser.Id,
		options.Description, options.Quota)

	safesCounterLock.Lock()
	defer safesCounterLock.Unlock()
	safesCounter++

	s := &Safe{
		Hnd:         safesCounter,
		CurrentUser: currentUser,
		CreatorId:   creatorId,
		Access:      access,
		Permission:  users[currentUser.Id],
		Name:        name,
		Id:          id,
		Description: options.Description,
		Storage:     store.Describe(),
		Quota:       options.Quota,
		QuotaGroup:  options.QuotaGroup,
		Size:        0,
		keystore:    keystore,
		store:       store,
		users:       users,
		usersLock:   sync.Mutex{},

		background:     time.NewTicker(time.Minute),
		syncUsers:      make(chan bool),
		uploadFile:     make(chan bool),
		compactHeaders: make(chan CompactHeader),
		quit:           make(chan bool),
		wg:             sync.WaitGroup{},
	}
	go backgroundJob(s)
	return s, nil
}
