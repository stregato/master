package safe

import (
	"path"
	"time"

	"github.com/stregato/master/woland/core"
	"github.com/stregato/master/woland/security"
	"github.com/stregato/master/woland/storage"
)

// Initiates is a map of user id to secret message.
type Initiates map[string]string

func GetInitiates(s *Safe) (Initiates, error) {
	ls, err := s.stores[0].ReadDir(path.Join(s.Name, InitiateFolder), storage.Filter{})
	if core.IsErr(err, nil, "cannot read initiates in %s: %v", s.Name) {
		return nil, err
	}

	initiates := Initiates{}
	for _, l := range ls {
		if l.ModTime().Before(core.Now().Add(-time.Hour * 24)) {
			s.stores[0].Delete(path.Join(s.Name, InitiateFolder, l.Name()))
			continue
		}

		data, err := storage.ReadFile(s.stores[0], path.Join(s.Name, InitiateFolder, l.Name()))
		if core.IsErr(err, nil, "cannot read initiate %s in %s: %v", l.Name(), s.Name) {
			continue
		}

		initiates[l.Name()] = string(data)
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
