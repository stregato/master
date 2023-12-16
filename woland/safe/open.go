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

	//ForceCreate
	ForceCreate bool

	//SyncUsersRefreshRate is the period for refreshing the access control list. Default is 10 minutes.
	SyncUsersRefreshRate time.Duration

	// AdaptiveSync dynamically modifies the sync period based on data availability and API calls
	AdaptiveSync bool

	//Notification is
	Notification chan Header
}

func Open(currentUser security.Identity, access string, options OpenOptions) (*Safe, error) {
	name, id, creatorId, url, err := DecodeAccess(currentUser, access)
	if core.IsErr(err, nil, "invalid access token 'account'") {
		return nil, err
	}

	now := core.Now()
	store, err := storage.Open(url)
	if core.IsErr(err, nil, "cannot connect to %s: %v", name) {
		return nil, err
	}
	core.Info("connected to %s in %v", name, core.Since(now))

	now = core.Now()
	manifest, err := readManifestFile(name, store, creatorId)
	if core.IsErr(err, nil, "cannot read manifest file in %s: %v", name) {
		return nil, err
	}
	core.Info("read manifest file of %s in %v", name, core.Since(now))

	size, err := getSafeSize(name)
	if core.IsErr(err, nil, "cannot get size of %s: %v", name) {
		return nil, err
	}

	users, err := getUsersFromDB(name)
	if core.IsErr(err, nil, "cannot get users in %s: %v", name) {
		return nil, err
	}

	s := Safe{
		Hnd:         safesCounter,
		CurrentUser: currentUser,
		Access:      access,
		Name:        name,
		Id:          id,
		Description: manifest.Description,
		CreatorId:   creatorId,
		Storage:     store.Describe(),
		Quota:       manifest.Quota,
		QuotaGroup:  manifest.QuotaGroup,
		Size:        size,
		Permission:  users[currentUser.Id],

		store:     store,
		users:     users,
		keystore:  readKeystoreFromDB(name),
		usersLock: sync.Mutex{},

		background:     time.NewTicker(time.Minute),
		syncUsers:      make(chan bool),
		uploadFile:     make(chan UploadTask),
		compactHeaders: make(chan CompactHeader),
		quit:           make(chan bool),
		wg:             sync.WaitGroup{},
	}

	_, err = SyncUsers(&s)
	if core.IsErr(err, nil, "cannot sync users in %s: %v", name) {
		return nil, err
	}

	// now = core.Now()
	// users, _, err := syncUsers(name, store, currentUser, creatorId, false)
	// if core.IsErr(err, nil, "cannot sync users in %s: %v", name) {
	// 	return nil, err
	// }
	// core.Info("synchorized users of %s in %v", name, core.Since(now))

	// keystore, _, err := syncKeystore(store, name, currentUser, users)
	// if core.IsErr(err, nil, "cannot read keystores in %s: %v", name) {
	// 	return nil, err
	// }
	// core.Info("synchorized keystore of %s in %v", name, core.Since(now))

	if s.Permission == 0 {
		if options.InitiateSecret != "" { // if current user is not in the ACL, create an initiate file
			core.Info("creating initiate file for %s with secret %s", currentUser.Id, options.InitiateSecret)
			createInitiateFile(name, store, currentUser, options.InitiateSecret)
		}
		return nil, fmt.Errorf("access pending")
	}

	if s.Permission == Suspended {
		return nil, fmt.Errorf("access denied")
	}

	safesCounterLock.Lock()
	safesCounter++
	safesCounterLock.Unlock()

	go backgroundJob(&s)

	core.Info("safe opened: name %s, creator %s, description %s, quota %d, #users %d, keystore %d", name,
		currentUser.Id, manifest.Description, manifest.Quota, len(s.users), s.keystore.LastKeyId)

	return &s, nil
}

// func connect(urls []string, name string, aesKey []byte) (stores []storage.Store, failedUrls []string, err error) {
// 	var wg sync.WaitGroup
// 	var lock sync.Mutex
// 	var elapsed = make([]time.Duration, len(urls))
// 	stores = make([]storage.Store, len(urls))

// 	if len(urls) == 0 {
// 		return nil, nil, fmt.Errorf("no url provided")
// 	}

// 	for idx, u := range urls {
// 		wg.Add(1)
// 		go func(idx int, u string) {
// 			defer wg.Done()
// 			start := core.Now()
// 			s, err := storage.Open(u)
// 			if core.IsErr(err, nil, "cannot connect to store %s: %v", u, err) {
// 				lock.Lock()
// 				failedUrls = append(failedUrls, u)
// 				lock.Unlock()
// 				return
// 			}
// 			if aesKey != nil {
// 				s = storage.EncryptNames(s, aesKey, aesKey, true)
// 			}
// 			stores[idx] = s
// 			elapsed[idx] = core.Since(start)
// 		}(idx, u)
// 	}
// 	wg.Wait()

// 	sort.Slice(stores, func(i, j int) bool {
// 		if stores[i] == nil {
// 			return false
// 		}
// 		if stores[j] == nil {
// 			return true
// 		}
// 		return elapsed[i] < elapsed[j]
// 	})

// 	if store == nil {
// 		return nil, failedUrls, ErrNoStoreAvailable
// 	}
// 	for idx, s := range stores {
// 		if s == nil {
// 			return stores[:idx], failedUrls, nil
// 		}
// 	}
// 	return stores, failedUrls, nil
// }
