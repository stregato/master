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
	MinimalSyncTime time.Duration `json:"minimalSyncTime"` // MinimalSyncTime is the minimal time between syncs
}

const (
	DefaultChangeLogWatch = time.Minute
	DefaultReplicaWatch   = 10 * time.Minute
)

// Create creates a new safe with the given name and store. The current user is the creator of the safe and it is
// automatically added to the list of users with creator permissions. Other users are optional.
func Create(currentUser security.Identity, name string, storeConfig StoreConfig, users Users, options CreateOptions) (*Safe, error) {
	now := core.Now()
	name, err := validName(name)
	if core.IsErr(err, nil, "invalid name %s: %v", name) {
		return nil, err
	}
	storeConfig.Primary = true

	primary, err := storage.Open(storeConfig.Url)
	if core.IsErr(err, nil, "cannot open store %s: %v", storeConfig.Url) {
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
		primary.Delete(name)
	} else {
		return nil, fmt.Errorf("safe already exist: name %s", name)
	}
	err = resetSafeInDB(name)
	if core.IsErr(err, nil, "cannot reset safe information in db: %v") {
		return nil, err
	}

	if options.ChangeLogWatch == 0 {
		options.ChangeLogWatch = DefaultChangeLogWatch
	}
	if options.ReplicaWatch == 0 {
		options.ReplicaWatch = DefaultReplicaWatch
	}

	err = writeManifest(name, primary, currentUser, Manifest{
		CreatorId:   creatorId,
		Description: options.Description,
	})
	if core.IsErr(err, nil, "cannot write manifest file in %s: %v", name) {
		return nil, err
	}

	err = writePermissionChange(primary, name, currentUser, users)
	if core.IsErr(err, nil, "cannot write permission change in %s: %v", name) {
		return nil, err
	}
	err = writeKeyStoreFile(primary, name, currentUser, keystore, users)
	if core.IsErr(err, nil, "cannot write keystore in %s: %v", name) {
		return nil, err
	}

	_, err = syncIdentities(primary, name, currentUser)
	if core.IsErr(err, nil, "cannot sync identities in %s: %v", name) {
		return nil, err
	}

	config := safeConfig{
		Description: options.Description,
		Keystore:    keystore,
		Users:       users,
	}
	err = setSafeConfigToDB(name, config)
	if core.IsErr(err, nil, "cannot write config of safe %s to DB: %v", name) {
		return nil, err
	}

	err = SetCached(name, primary, "config/.access.touch", nil, currentUser.Id)
	if core.IsErr(err, nil, "cannot create touch file in %s: %v", name) {
		return nil, err
	}

	safesCounterLock.Lock()
	safesCounter++

	s := &Safe{
		Hnd:            safesCounter,
		CurrentUser:    currentUser,
		CreatorId:      creatorId,
		Connected:      true,
		Permission:     users[currentUser.Id],
		Name:           name,
		Description:    options.Description,
		Keystore:       keystore,
		Users:          users,
		PrimaryStore:   primary,
		SecondaryStore: primary,
		storeUrl:       storeConfig.Url,
		usersLock:      sync.Mutex{},
		background:     time.NewTicker(time.Minute),
		syncUsers:      make(chan bool),
		uploadFile:     make(chan UploadTask),
		enforceQuota:   make(chan bool),
		connect:        make(chan bool),
		compactHeaders: make(chan CompactHeader),
		storeSizes:     map[string]int64{},
		quit:           make(chan bool),
		wg:             sync.WaitGroup{},
		lastBucketSync: map[string]time.Time{},
		storeLock:      sync.Mutex{},
	}
	safesCounterLock.Unlock()

	err = AddStore(s, storeConfig)
	if core.IsErr(err, nil, "cannot add store %s/%s: %v", name, storeConfig.Url, err) {
		return nil, err
	}

	go backgroundJob(s)

	core.Info("safe  %s created in %s: creator %s, description %s", name, core.Since(now), currentUser.Id,
		options.Description)

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
	res, err := sql.Exec("DELETE_STORES", sql.Args{"safe": name})
	if core.IsErr(err, nil, "cannot delete stores of safe %s from DB: %v", name) {
		return err
	}
	n, _ := res.RowsAffected()
	core.Info("deleted %d stores of safe %s from DB", n, name)

	_, err = sql.Exec("DELETE_SAFE_HEADERS", sql.Args{"safe": name})
	if core.IsErr(err, nil, "cannot wipe DB headers for safe %s: %v", name, err) {
		return err
	}
	n, _ = res.RowsAffected()
	core.Info("deleted %d headers of safe %s from DB", n, name)

	_, err = sql.Exec("DELETE_SAFE_USERS", sql.Args{"safe": name})
	if core.IsErr(err, nil, "cannot wipe DB users for safe %s: %v", name, err) {
		return err
	}
	n, _ = res.RowsAffected()
	core.Info("deleted %d users of safe %s from DB", n, name)

	_, err = sql.Exec("DELETE_SAFE_CONFIGS", sql.Args{"safe": name})
	if core.IsErr(err, nil, "cannot wipe DB configs for safe %s: %v", name, err) {
		return err
	}
	n, _ = res.RowsAffected()
	core.Info("deleted %d configs of safe %s from DB", n, name)

	core.Info("successfully reset DB info for safe %s", name)
	return nil
}
