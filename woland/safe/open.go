package safe

import (
	"fmt"
	"time"

	"github.com/code-to-go/woland/core"
	"github.com/code-to-go/woland/security"
	store "github.com/code-to-go/woland/storage"
)

var ErrNoStoreAvailable = fmt.Errorf("no store available")

var DataFolder = "data"
var IdentitiesFolder = "users"

type OpenSettings struct {
	//ForceCreate
	ForceCreate bool

	//SyncPeriod is the period for synchronization with the remote storage
	SyncPeriod time.Duration

	// AdaptiveSync dynamically modifies the sync period based on data availability and API calls
	AdaptiveSync bool

	//Notification is
	Notification chan bool

	//NoDefaultGroup prevents the creation of a default security group
	NoDefaultGroup bool
}

type Safe struct {
	Self     security.Identity
	Name     string
	store    store.Store
	storeUrl string
	groups   []string
	keys     map[uint64][]byte
}

func Open(self security.Identity, access string, settings OpenSettings) (*Safe, error) {
	s := Safe{
		Self: self,
	}
	a, err := unwrapAccess(self, access)
	if core.IsErr(err, "invalid access token 'account'") {
		return nil, err
	}

	err = s.connect(a)
	if core.IsErr(err, "cannot connect to %s: %v", a.Name) {
		return nil, err
	}

	err = s.loadGroups()
	if core.IsErr(err, "cannot read security groups in %s: %v", s) {
		return nil, err
	}

	return &s, nil
}

func (s *Safe) connect(a _access) error {
	fastestRoundTrip := time.Hour

	for _, url := range a.Stores {
		start := core.Now()
		store, err := store.Open(url)
		if core.IsWarn(err, "cannot connect to store %s: %v") {
			continue
		}
		elapsed := core.Since(start)
		if elapsed > fastestRoundTrip {
			store.Close()
		} else {
			fastestRoundTrip = elapsed
			s.store = store
			s.storeUrl = url
		}
	}

	if s.store == nil {
		return ErrNoStoreAvailable
	}
	return nil
}

func (s *Safe) loadKeys() error {
	//	for _, g := range s.groups {
	// ls, err := s.store.ReadDir(path.Join(s.Name, DataFolder, g), 0)
	// if core.IsErr(err, "cannot read keys in %s/%s: %v", s.store, s.Name) {
	// 	return err
	// }

	// }
	return nil
}
