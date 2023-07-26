package portal

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

func Open(currentUser security.Identity, token string, options OpenOptions) (*Portal, error) {
	portalName, key, urls, err := DecodeToken(currentUser, token)
	if core.IsErr(err, "invalid access token 'account'") {
		return nil, err
	}

	store, url, err := connect(urls)
	if core.IsErr(err, "cannot connect to %s: %v", portalName) {
		return nil, err
	}
	store = storage.Sub(store, portalName, true)

	if key != nil {
		store = storage.EncryptNames(store, key, key, true)
	}

	identities, err := readIdentities(store)
	if core.IsErr(err, "cannot read identities in %s: %v", portalName) {
		return nil, err
	}
	if _, ok := identities[currentUser.ID]; !ok {
		err = writeIdentity(store, currentUser)
		if core.IsErr(err, "cannot write identity to store %s: %v", store) {
			return nil, err
		}
	}

	zones, err := getZonesFromDB(portalName)
	if core.IsErr(err, "cannot read zones in %s: %v", portalName) {
		return nil, err
	}
	for zoneName, zone := range zones {
		err = readZone(currentUser, store, portalName, zoneName, &zone)
		if err == ErrZoneNoAuth {
			delete(zones, zoneName)
			continue
		}
		if len(zone.Acls) > MaxACLFilesInZone {
			writeZone(currentUser, store, portalName, zoneName, &zone)
		}

		core.IsErr(err, "cannot sync zone %s: %v", zoneName, err)
	}

	s := Portal{
		CurrentUser: currentUser,
		Name:        portalName,

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
