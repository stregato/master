package safe

import (
	"fmt"
	"time"

	"github.com/stregato/master/massolit/core"
	"github.com/stregato/master/massolit/security"
	"github.com/stregato/master/massolit/storage"
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
	Notification chan File
}

func Open(currentUser security.Identity, token string, options OpenOptions) (*Safe, error) {
	path, creatorId, aesKey, urls, err := DecodeAccess(currentUser, token)
	if core.IsErr(err, nil, "invalid access token 'account'") {
		return nil, err
	}

	store, url, err := connect(urls)
	if core.IsErr(err, nil, "cannot connect to %s: %v", path) {
		return nil, err
	}
	store = storage.Sub(store, path, true)

	if aesKey != nil {
		store = storage.EncryptNames(store, aesKey, aesKey, true)
	}

	manifest, err := readManifestFile(store, creatorId)
	if core.IsErr(err, nil, "cannot read manifest file in %s: %v", path) {
		return nil, err
	}

	admins, err := readAdminsFile(store, creatorId)
	if core.IsErr(err, nil, "cannot read admins file in %s: %v", path) {
		return nil, err
	}

	identities, err := readIdentities(store)
	if core.IsErr(err, nil, "cannot read identities in %s: %v", path) {
		return nil, err
	}

	var identityFound bool
	for _, identity := range identities {
		if identity.ID == currentUser.ID {
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

	primaryKey, err := readKeystore(store, path, currentUser, admins, manifest.Relaxed)
	if core.IsErr(err, nil, "cannot read keystore in %s: %v", path) {
		return nil, err
	}

	s := Safe{
		CurrentUser: currentUser,
		Name:        path,
		Description: manifest.Description,
		CreatorId:   creatorId,
		Admins:      admins,
		Relaxed:     manifest.Relaxed,
		primaryKey:  primaryKey,
		identities:  identities,
		store:       store,
		storeUrl:    url,
	}

	return &s, nil
}

func connect(urls []string) (store storage.Store, url string, err error) {
	fastestRoundTrip := time.Hour

	for _, u := range urls {
		start := core.Now()
		s, err := storage.Open(u)
		if core.IsWarn(err, "cannot connect to store %s: %v", u) {
			continue
		}
		elapsed := core.Since(start)
		if elapsed > fastestRoundTrip {
			s.Close()
		} else {
			fastestRoundTrip = elapsed
			store, url = s, u
		}
	}

	if store == nil {
		return nil, "", ErrNoStoreAvailable
	}
	return store, url, nil
}

func readAdminsFile(s storage.Store, creatorId string) (map[string]Level2, error) {
	var adminFile AdminFile

	data, err := storage.ReadFile(s, "admins.json")
	if core.IsErr(err, nil, "cannot read admins file: %v", err) {
		return nil, err
	}

	signedBy, err := security.Unmarshal(data, &adminFile, "signature")
	if core.IsErr(err, nil, "cannot read admins file: %v", err) {
		return nil, err
	}

	var admins = map[string]Level2{}
	var stack []Grant
	for _, grant := range adminFile.Grants {
		if grant.By == creatorId && grant.UserId == creatorId {
			stack = append(stack, grant)
			admins[grant.UserId] = grant.Level2
		}
	}

	for len(stack) > 0 {
		current := stack[len(stack)-1]
		stack = stack[:len(stack)-1]
		for _, grant := range adminFile.Grants {
			if grant.By == current.UserId && current.Level2 {
				admins[grant.UserId] = grant.Level2
				stack = append(stack, grant)
			}
		}
	}

	if !admins[signedBy] {
		return nil, fmt.Errorf("invalid admins file: not signed by level2 administrator")
	}

	return admins, nil
}

func readKeystore(s storage.Store, name string, currentUser security.Identity, admins Admins, relaxed bool) (primaryKey []byte, err error) {
	var keystore Keystore

	data, err := storage.ReadFile(s, "keystore.json")
	if core.IsErr(err, nil, "cannot read keystore file: %v", err) {
		return nil, err
	}

	signedBy, err := security.Unmarshal(data, &keystore, "signature")
	if core.IsErr(err, nil, "cannot read keystore file: %v", err) {
		return nil, err
	}

	if _, ok := admins[signedBy]; !ok {
		return nil, fmt.Errorf("invalid keystore file: not signed by administrator")
	}

	encryptedKey, ok := keystore.Keys[currentUser.ID]
	if !ok {
		return nil, fmt.Errorf(ErrNoAuth, currentUser.Nick, currentUser.ID, name)
	}

	primaryKey, err = security.EcDecrypt(currentUser, encryptedKey)
	if core.IsErr(err, nil, "cannot decrypt primary key: %v", err) {
		return nil, err
	}

	return primaryKey, nil
}
