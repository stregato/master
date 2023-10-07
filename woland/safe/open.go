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

type OpenOptions struct {
	//ForceCreate
	ForceCreate bool

	//SyncPeriod is the period for synchronization with the remote storage
	SyncPeriod time.Duration

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

	stores, _, err := connect(urls, name, aesKey)
	if core.IsErr(err, nil, "cannot connect to %s: %v", name) {
		return nil, err
	}

	store := stores[0]
	identities, err := syncIdentities(store, name, currentUser)
	if core.IsErr(err, nil, "cannot sync identities in %s: %v", name) {
		return nil, err
	}

	manifest, err := readManifestFile(store, creatorId)
	if core.IsErr(err, nil, "cannot read manifest file in %s: %v", name) {
		return nil, err
	}

	users, newestChangeFile, err := readChangeLogs(store, name, currentUser, creatorId, "")
	if core.IsErr(err, nil, "cannot read change logs in %s: %v", name) {
		return nil, err
	}

	for _, identity := range identities {
		if _, ok := users[identity.Id]; !ok {
			users[identity.Id] = PermissionWait
		}
	}

	keyId, key, keys, _, err := readKeystores(store, name, currentUser, users)
	if core.IsErr(err, nil, "cannot read keystores in %s: %v", name) {
		return nil, err
	}
	keys[keyId] = key

	size, err := getSafeSize(name)
	if core.IsErr(err, nil, "cannot get size of %s: %v", name) {
		return nil, err
	}

	s := Safe{
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
		users:       users,

		keyId:                keyId,
		keys:                 keys,
		identities:           identities,
		stores:               stores,
		newestChangeFile:     newestChangeFile,
		lastIdentitiesUpdate: core.Now(),
	}

	return &s, nil
}

func syncIdentities(store storage.Store, name string, currentUser security.Identity) ([]security.Identity, error) {
	identities, err := readIdentities(store)
	if core.IsErr(err, nil, "cannot read identities in %s: %v", name) {
		return nil, err
	}

	var identityFound bool
	for _, identity := range identities {
		if identity.Id == currentUser.Id {
			identityFound = true
			break
		}
	}
	if !identityFound {
		err = writeIdentity(store, currentUser)
		if core.IsErr(err, nil, "cannot write identity to store %s: %v", store) {
			return nil, err
		}
		identities = append(identities, currentUser.Public())
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
