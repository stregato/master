package safe

import (
	"fmt"
	"sync"
	"time"

	"github.com/stregato/master/woland/core"
	"github.com/stregato/master/woland/security"
	"github.com/stregato/master/woland/storage"
)

var ErrNoStoreAvailable = fmt.Errorf("no store available")

var IdentitiesFolder = ".identities"
var MaxACLFilesInZone = 4
var DefaultSyncUsersRefreshRate = 10 * time.Minute

type OpenOptions struct {
	//InitiateSecret is the information the admin receives when a user requests access to a safe
	InitiateSecret string

	//Reset cleans the DB before opening the safe
	Reset bool

	//Notification is
	Notification chan Header
}

func Open(currentUser security.Identity, name string, storeUrl string, creatorId string, options OpenOptions) (*Safe, error) {
	name, err := validName(name)
	if core.IsErr(err, nil, "invalid name %s: %v", name) {
		return nil, err
	}

	if options.Reset {
		resetSafeInDB(name)
	}

	safesCounterLock.Lock()
	s := &Safe{
		Hnd:         safesCounter,
		CurrentUser: currentUser,
		CreatorId:   creatorId,
		Name:        name,

		usersLock:      sync.Mutex{},
		syncUsers:      make(chan bool),
		uploadFile:     make(chan UploadTask),
		compactHeaders: make(chan CompactHeader),
		quit:           make(chan bool),
		wg:             sync.WaitGroup{},
		lastBucketSync: map[string]time.Time{},
	}
	safesCounter++
	safesCounterLock.Unlock()

	now := core.Now()
	err = connect(s, storeUrl)
	if core.IsErr(err, nil, "cannot connect to %s: %v", name) {
		return nil, err
	}
	core.Info("connected to %s in %v", name, core.Since(now))

	now = core.Now()
	manifest, err := readManifestFile(name, s.primary, creatorId)
	if core.IsErr(err, nil, "cannot read manifest file in %s: %v", name) {
		return nil, err
	}
	s.Description = manifest.Description
	s.MinimalSyncTime = manifest.MinimalSyncTime
	core.Info("read manifest file of %s in %v", name, core.Since(now))

	now = core.Now()
	users, err := getUsersFromDB(name)
	if core.IsErr(err, nil, "cannot get users in %s: %v", name) {
		return nil, err
	}
	s.users = users
	s.Permission = users[currentUser.Id]
	s.keystore = readKeystoreFromDB(name)

	core.Info("read users from DB of %s in %v", name, core.Since(now))

	now = core.Now()
	err = syncStores(s)
	if core.IsErr(err, nil, "cannot sync stores in %s: %v", name) {
		return nil, err
	}
	core.Info("synchorized stores of %s in %v", name, core.Since(now))

	now = core.Now()
	_, err = SyncUsers(s)
	if core.IsErr(err, nil, "cannot sync users in %s: %v", name) {
		return nil, err
	}
	core.Info("synchorized users of %s in %v", name, core.Since(now))

	if s.Permission == 0 {
		if options.InitiateSecret != "" { // if current user is not in the ACL, create an initiate file
			core.Info("creating initiate file for %s with secret %s", currentUser.Id, options.InitiateSecret)
			createInitiateFile(name, s.primary, currentUser, options.InitiateSecret)
		}
		return nil, fmt.Errorf("access pending")
	}

	if s.Permission == Suspended {
		return nil, fmt.Errorf("access denied")
	}

	s.background = time.NewTicker(time.Minute)
	go backgroundJob(s)

	core.Info("safe opened: name %s, creator %s, description %s, quota %d, #users %d, keystore %d", name,
		currentUser.Id, manifest.Description, manifest.Quota, len(s.users), s.keystore.LastKeyId)

	return s, nil
}

func connect(s *Safe, storeUrl string) error {
	configs, err := getStoreConfigsFromDB(s.Name)
	if core.IsErr(err, nil, "cannot get stores for safe %s: %v", s.Name, err) {
		return err
	}
	if len(configs) == 0 {
		store, err := storage.Open(storeUrl)
		if core.IsErr(err, nil, "cannot connect to store %s: %v", storeUrl, err) {
			return err
		}

		s.primary = store
		s.stores = []storage.Store{store}
		core.Info("connected to primary of %s for first time in %v", s.Name, core.Since(core.Now()))
		return nil
	}

	ch := make(chan storage.Store, len(configs))
	s.StoreConfigs = configs

	now := core.Now()
	for _, c := range s.StoreConfigs {
		go func(c StoreConfig) {
			store, err := storage.Open(c.Url)
			if core.IsErr(err, nil, "cannot connect to store %s: %v", c.Url, err) {
				ch <- nil
				return
			}
			if c.Primary {
				core.Info("connected to primary store %s of %s in %v", store, s.Name, core.Since(now))
				s.primary = store
			} else {
				core.Info("connected to secondary store %s of %s in %v", store, s.Name, core.Since(now))
			}
			ch <- store
		}(c)
	}

	for i := 0; i < len(configs); i++ {
		store := <-ch
		if store != nil {
			s.stores = append(s.stores, store)
			if s.primary == store {
				core.Info("connected to %s in %v", s.Name, core.Since(now))
				go func(count int) {
					for j := 0; j < count; j++ {
						store := <-ch
						if store != nil {
							s.stores = append(s.stores, store)
						}
					}
				}(len(configs) - i - 1)
				return nil
			}
		}
	}

	return ErrNoStoreAvailable
}
