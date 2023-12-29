package safe

import (
	"fmt"
	"strings"
	"sync"
	"time"

	"github.com/godruoyi/go-snowflake"

	"github.com/stregato/master/woland/core"
	"github.com/stregato/master/woland/security"
	"github.com/stregato/master/woland/sql"
	"github.com/stregato/master/woland/storage"
)

type CreateOptions struct {
	Wipe            bool          `json:"wipe"`            // Wipe is true if the safe should be wiped before creating it
	Description     string        `json:"description"`     // Description of the safe
	ChangeLogWatch  time.Duration `json:"changeLogWatch"`  // ChangeLogWatch is the period for watching changes in the change log
	ReplicaWatch    time.Duration `json:"replicaWatch"`    // ReplicaWatch is the period for synchronizing replicas
	Quota           int64         `json:"quota"`           // Quota is the maximum size of the safe in bytes
	QuotaGroup      string        `json:"quotaGroup"`      // QuotaGroup is the common prefix for the safes that share the quota
	MinimalSyncTime time.Duration `json:"minimalSyncTime"` // MinimalSyncTime is the minimal time between syncs
}

const (
	DefaultChangeLogWatch = time.Minute
	DefaultReplicaWatch   = 10 * time.Minute
)

// Create creates a new safe with the given name and store. The current user is the creator of the safe and it is
// automatically added to the list of users with creator permissions. Other users are optional.
func Create(currentUser security.Identity, name string, storeUrl string, users Users, options CreateOptions) (*Safe, error) {
	name, err := validName(name)
	if core.IsErr(err, nil, "invalid name %s: %v", name) {
		return nil, err
	}

	origin, err := storage.Open(storeUrl)
	if core.IsErr(err, nil, "cannot open store %s: %v", storeUrl) {
		return nil, err
	}

	creatorId := currentUser.Id
	keystore := Keystore{
		LastKeyId: snowflake.ID(),
		Keys:      map[uint64][]byte{},
	}
	keystore.Keys[keystore.LastKeyId] = core.GenerateRandomBytes(KeySize)
	if users == nil {
		users = make(Users)
	}
	users[creatorId] = Reader + Standard + Admin + Creator

	if options.Wipe {
		core.Info("wiping safe: name %s", name)
		origin.Delete(name)
		resetSafeInDB(name)
	} else {
		return nil, fmt.Errorf("safe already exist: name %s", name)
	}

	if options.ChangeLogWatch == 0 {
		options.ChangeLogWatch = DefaultChangeLogWatch
	}
	if options.ReplicaWatch == 0 {
		options.ReplicaWatch = DefaultReplicaWatch
	}

	err = writeManifestFile(name, origin, currentUser, manifestFile{
		CreatorId:       creatorId,
		Description:     options.Description,
		ChangeLogWatch:  options.ChangeLogWatch,
		ReplicaWatch:    options.ReplicaWatch,
		Quota:           options.Quota,
		QuotaGroup:      options.QuotaGroup,
		MinimalSyncTime: options.MinimalSyncTime,
	})
	if core.IsErr(err, nil, "cannot write manifest file in %s: %v", name) {
		return nil, err
	}

	err = writePermissionChange(origin, name, currentUser, users)
	if core.IsErr(err, nil, "cannot write permission change in %s: %v", name) {
		return nil, err
	}
	setUserInDB(name, currentUser.Id, Reader|Standard|Admin|Creator)

	err = writeKeyStoreToDB(name, keystore)
	if core.IsErr(err, nil, "cannot write keystore in DB for %s: %v", name) {
		return nil, err
	}
	err = writeKeyStoreFile(origin, name, currentUser, keystore, users)
	if core.IsErr(err, nil, "cannot write keystore in %s: %v", name) {
		return nil, err
	}

	_, err = syncIdentities(origin, name, currentUser)
	if core.IsErr(err, nil, "cannot sync identities in %s: %v", name) {
		return nil, err
	}

	err = SetCached(name, origin, "config/.access.touch", nil, currentUser.Id)
	if core.IsErr(err, nil, "cannot create touch file in %s: %v", name) {
		return nil, err
	}

	core.Info("safe created: name %s, creator %s, description %s, quota %d", name, currentUser.Id,
		options.Description, options.Quota)

	safesCounterLock.Lock()
	safesCounter++

	s := &Safe{
		Hnd:             safesCounter,
		CurrentUser:     currentUser,
		CreatorId:       creatorId,
		Permission:      users[currentUser.Id],
		Name:            name,
		Description:     options.Description,
		Size:            0,
		MinimalSyncTime: options.MinimalSyncTime,

		primary:        origin,
		stores:         []storage.Store{origin},
		keystore:       keystore,
		users:          users,
		usersLock:      sync.Mutex{},
		background:     time.NewTicker(time.Minute),
		syncUsers:      make(chan bool),
		uploadFile:     make(chan UploadTask),
		compactHeaders: make(chan CompactHeader),
		quit:           make(chan bool),
		wg:             sync.WaitGroup{},
		lastBucketSync: map[string]time.Time{},
	}
	safesCounterLock.Unlock()

	storeConfig := StoreConfig{Url: storeUrl, Quota: options.Quota, Primary: true, CreatorId: creatorId}
	err = AddStore(s, storeConfig)
	if core.IsErr(err, nil, "cannot add store %s/%s: %v", name, storeUrl, err) {
		return nil, err
	}

	go backgroundJob(s)
	return s, nil
}

var forbiddenChars = []rune{'.', ';', '/', '`', '\'', '@', '"', '(', ')',
	'[', ']', '{', '}', '<', '>', ',', '!', '#', '$', '%', '^', '&', '*',
	'+', '=', '|', '\\', '~', ' '}

func validName(name string) (string, error) {
	for _, c := range name {
		for _, f := range forbiddenChars {
			if c == f {
				return "", fmt.Errorf("invalid character %c in name %s", c, name)
			}
		}
	}
	return strings.ToLower(name), nil
}

func resetSafeInDB(name string) error {
	_, err := sql.Exec("DEL_STORES", sql.Args{"name": name})
	if core.IsErr(err, nil, "cannot delete stores of safe %s from DB: %v", name) {
		return err
	}

	_, err = sql.Exec("DELETE_SAFE_HEADERS", sql.Args{"safe": name})
	if core.IsErr(err, nil, "cannot wipe DB headers for safe %s: %v", name, err) {
		return err
	}

	_, err = sql.Exec("DELETE_SAFE_USERS", sql.Args{"safe": name})
	if core.IsErr(err, nil, "cannot wipe DB users for safe %s: %v", name, err) {
		return err
	}

	_, err = sql.Exec("DELETE_SAFE_CONFIGS", sql.Args{"safe": name})
	if core.IsErr(err, nil, "cannot wipe DB configs for safe %s: %v", name, err) {
		return err
	}

	return nil
}
