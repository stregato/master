package safe

import (
	"fmt"
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

func Open(currentUserId string, access string, options OpenOptions) (*Safe, error) {
	currentUser, ok, err := security.GetIdentity(currentUserId)
	if core.IsErr(err, "cannot get current user: %v", err) {
		return nil, err
	}
	if !ok {
		return nil, fmt.Errorf("cannot find current user '%s'", currentUserId)
	}

	safeName, key, urls, issuerId, err := unwrapToken(currentUser, access)
	if core.IsErr(err, "invalid access token 'account'") {
		return nil, err
	}

	store, url, err := connect(urls)
	if core.IsErr(err, "cannot connect to %s: %v", safeName) {
		return nil, err
	}
	store = storage.Sub(store, safeName, true)

	if key != nil {
		store = storage.EncryptNames(store, key, key, true)
	}

	identities, err := readIdentities(store)
	if core.IsErr(err, "cannot read identities in %s: %v", safeName) {
		return nil, err
	}
	if _, ok := identities[currentUser.ID()]; !ok {
		err = writeIdentity(store, currentUser)
		if core.IsErr(err, "cannot write identity to store %s: %v", store) {
			return nil, err
		}
	}

	zones, err := getZonesFromDB(safeName)
	if core.IsErr(err, "cannot read zones in %s: %v", safeName) {
		return nil, err
	}
	for zoneName, zone := range zones {
		err = readZone(currentUser, store, safeName, zoneName, &zone)
		if err == ErrZoneNoAuth {
			delete(zones, zoneName)
			continue
		}
		if len(zone.Acls) > MaxACLFilesInZone {
			writeZone(currentUser, store, safeName, zoneName, &zone)
		}

		core.IsErr(err, "cannot sync zone %s: %v", zoneName, err)
	}

	s := Safe{
		CurrentUser: currentUser,
		Name:        safeName,
		IssuerId:    issuerId,

		zones:    zones,
		store:    store,
		storeUrl: url,
	}

	return &s, nil
}

func connect(urls []string) (store storage.Store, url string, err error) {
	fastestRoundTrip := time.Hour

	for _, u := range urls {
		start := core.Now()
		s, err := storage.Open(u)
		if core.IsWarn(err, "cannot connect to store %s: %v") {
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
