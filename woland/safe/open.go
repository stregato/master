package safe

import (
	"fmt"
	"sort"
	"sync"
	"time"

	"github.com/stregato/master/woland/core"
	"github.com/stregato/master/woland/security"
	"github.com/stregato/master/woland/storage"
)

var ErrNoStoreAvailable = fmt.Errorf("no store available")

var UsersFolder = "users"
var UserFile = ".user"
var MaxACLFilesInZone = 4
var DefaultSyncUsersRefreshRate = 10 * time.Minute

type OpenOptions struct {
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
	name, creatorId, aesKey, urls, err := DecodeAccess(currentUser, access)
	if core.IsErr(err, nil, "invalid access token 'account'") {
		return nil, err
	}

	now := core.Now()
	stores, _, err := connect(urls, name, aesKey)
	if core.IsErr(err, nil, "cannot connect to %s: %v", name) {
		return nil, err
	}
	core.Info("connected to %s in %v", name, core.Since(now))

	now = core.Now()
	store := stores[0]
	manifest, err := readManifestFile(name, store, creatorId)
	if core.IsErr(err, nil, "cannot read manifest file in %s: %v", name) {
		return nil, err
	}
	core.Info("read manifest file of %s in %v", name, core.Since(now))

	now = core.Now()
	users, _, err := syncUsers(name, store, currentUser, creatorId, false)
	if core.IsErr(err, nil, "cannot sync users in %s: %v", name) {
		return nil, err
	}
	core.Info("synchorized users of %s in %v", name, core.Since(now))

	keystore, _, err := syncKeystore(store, name, currentUser, users)
	if core.IsErr(err, nil, "cannot read keystores in %s: %v", name) {
		return nil, err
	}
	core.Info("synchorized keystore of %s in %v", name, core.Since(now))

	if keystore.LastKeyId == 0 {
		return nil, fmt.Errorf("no key found")
	}

	size, err := getSafeSize(name)
	if core.IsErr(err, nil, "cannot get size of %s: %v", name) {
		return nil, err
	}

	safesCounterLock.Lock()
	safesCounter++
	s := Safe{
		Hnd:         safesCounter,
		CurrentUser: currentUser,
		Access:      access,
		Name:        name,
		Permission:  users[currentUser.Id],
		Description: manifest.Description,
		CreatorId:   creatorId,
		Storage:     stores[0].Describe(),
		Quota:       manifest.Quota,
		QuotaGroup:  manifest.QuotaGroup,
		Size:        size,

		keystore:  keystore,
		stores:    stores,
		users:     users,
		usersLock: sync.Mutex{},
		syncUsers: time.NewTicker(10 * time.Minute),
		uploads:   time.NewTicker(time.Minute),
		upload:    make(chan bool),
		quit:      make(chan bool),
		wg:        sync.WaitGroup{},
	}
	go syncUserJob(&s)
	go uploadJob(&s)

	safesCounterLock.Unlock()

	core.Info("safe opened: name %s, creator %s, description %s, quota %d, keystore %v", name,
		currentUser.Id, manifest.Description, manifest.Quota, keystore)

	return &s, nil
}

func syncIdentities(store storage.Store, name string, currentUser security.Identity) (new []security.Identity, err error) {
	synced, err := GetCached(name, store, ".identities.touch", nil)
	if core.IsErr(err, nil, "cannot sync touch file in %s: %v", name) {
		return nil, err
	}

	if synced {
		core.Info("identities in %s are up to date", name)
		return nil, nil
	}
	identities, err := readIdentities(store)
	if core.IsErr(err, nil, "cannot read identities in %s: %v", name) {
		return nil, err
	}

	for _, identity := range identities {
		core.Info("compare %s with %s", identity.Id, currentUser.Id)
		if identity.Id == currentUser.Id {
			err = SetCached(name, store, ".identities.touch", nil, false)
			if core.IsErr(err, nil, "cannot write touch file in %s: %v", name) {
				return nil, err
			}
			return identities, nil
		}
	}

	err = writeIdentity(store, currentUser)
	if core.IsErr(err, nil, "cannot write identity to store %s: %v", store) {
		return nil, err
	}
	identities = append(identities, currentUser.Public())
	core.Info("current user %s not found in %s identities, added it", currentUser.Id, name)

	err = SetCached(name, store, ".identities.touch", nil, true)
	if core.IsErr(err, nil, "cannot write touch file in %s: %v", name) {
		return nil, err
	}
	return identities, nil
}

func connect(urls []string, name string, aesKey []byte) (stores []storage.Store, failedUrls []string, err error) {
	var wg sync.WaitGroup
	var lock sync.Mutex
	var elapsed = make([]time.Duration, len(urls))
	stores = make([]storage.Store, len(urls))

	if len(urls) == 0 {
		return nil, nil, fmt.Errorf("no url provided")
	}

	for idx, u := range urls {
		wg.Add(1)
		go func(idx int, u string) {
			defer wg.Done()
			start := core.Now()
			s, err := storage.Open(u)
			if core.IsErr(err, nil, "cannot connect to store %s: %v", u, err) {
				lock.Lock()
				failedUrls = append(failedUrls, u)
				lock.Unlock()
				return
			}
			s = storage.Sub(s, name, true)
			if aesKey != nil {
				s = storage.EncryptNames(s, aesKey, aesKey, true)
			}
			stores[idx] = s
			elapsed[idx] = core.Since(start)
		}(idx, u)
	}
	wg.Wait()

	sort.Slice(stores, func(i, j int) bool {
		if stores[i] == nil {
			return false
		}
		if stores[j] == nil {
			return true
		}
		return elapsed[i] < elapsed[j]
	})

	if stores[0] == nil {
		return nil, failedUrls, ErrNoStoreAvailable
	}
	for idx, s := range stores {
		if s == nil {
			return stores[:idx], failedUrls, nil
		}
	}
	return stores, failedUrls, nil
}
