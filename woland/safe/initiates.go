package safe

import (
	"path"
	"time"

	"github.com/stregato/master/woland/core"
	"github.com/stregato/master/woland/security"
	"github.com/stregato/master/woland/storage"
)

// Initiates is a map of user id to secret message.
type Initiate struct {
	Secret   string            `json:"secret"`
	Identity security.Identity `json:"identity"`
}

func GetInitiates(s *Safe) ([]Initiate, error) {
	store := s.primary
	ls, err := store.ReadDir(path.Join(s.Name, InitiateFolder), storage.Filter{})
	if core.IsErr(err, nil, "cannot read initiates in %s: %v", s.Name) {
		return nil, err
	}

	var initiates []Initiate

	for _, l := range ls {
		if l.ModTime().Before(core.Now().Add(-time.Hour * 24)) {
			store.Delete(path.Join(s.Name, InitiateFolder, l.Name()))
			continue
		}

		data, err := storage.ReadFile(store, path.Join(s.Name, InitiateFolder, l.Name()))
		if core.IsErr(err, nil, "cannot read initiate %s in %s: %v", l.Name(), s.Name) {
			continue
		}

		identity, err := security.GetIdentity(l.Name())
		if err == nil {
			initiates = append(initiates, Initiate{
				Secret:   string(data),
				Identity: identity,
			})
			continue
		}

		new, err := syncIdentities(store, s.Name, s.CurrentUser)
		if core.IsErr(err, nil, "cannot sync identities in %s: %v", s.Name) {
			continue
		}

		for _, n := range new {
			if n.Id == l.Name() {
				initiates = append(initiates, Initiate{
					Secret:   string(data),
					Identity: n,
				})
			}
		}
	}

	return initiates, nil
}

func createInitiateFile(safeName string, store storage.Store, currentUser security.Identity, initiateSecret string) error {
	err := storage.WriteFile(store, path.Join(safeName, InitiateFolder, currentUser.Id), []byte(initiateSecret))
	if core.IsErr(err, nil, "cannot write touch file in %s: %v", safeName) {
		return err
	}
	return nil
}

func deleteInitiateFile(safeName string, store storage.Store, userId string) error {
	err := store.Delete(path.Join(safeName, InitiateFolder, userId))
	if core.IsErr(err, nil, "cannot delete initiate file in %s: %v", safeName) {
		return err
	}
	return nil
}
