package safe

import (
	"fmt"
	"os"
	"path"

	"github.com/stregato/master/woland/core"
	"github.com/stregato/master/woland/security"
	"github.com/stregato/master/woland/storage"
)

var ErrSignatureMismatch = fmt.Errorf("provided signature does not match the expected identity")

// writeIdentity writes an identity to a store and update the DB
func writeIdentity(st storage.Store, self security.Identity) error {
	data, err := security.Marshal(self, self.Public(), "sg")
	if core.IsErr(err, nil, "cannot marshal identity %s: %v", self.Id) {
		return err
	}
	err = storage.WriteFile(st, path.Join(IdentitiesFolder, self.Id), data)
	if core.IsErr(err, nil, "cannot write identity %s: %v", self.Id) {
		return err
	}
	return nil
}

// readIdentities read identities from a store and update the DB when required
func readIdentities(st storage.Store) ([]security.Identity, error) {
	dbIdentities, err := security.GetIdentities()
	if core.IsErr(err, nil, "cannot read identitied from DB: %v") {
		return nil, err
	}

	m := map[string]security.Identity{}
	for _, i := range dbIdentities {
		m[i.Id] = i
	}

	ls, err := st.ReadDir(IdentitiesFolder, storage.Filter{})
	if !os.IsNotExist(err) && core.IsErr(err, nil, "cannot list identity files': %v", err) {
		return nil, err
	}
	core.Info("reading identities from %s, %d files found", IdentitiesFolder, len(ls))

	var identities []security.Identity
	for _, l := range ls {
		userId := l.Name()

		if identity, ok := m[userId]; ok && identity.ModTime.Before(l.ModTime()) {
			identities = append(identities, identity)
			core.Info("identity '%s' is up to date, using db copy %s[%s]", userId, identity.Nick, identity.Id)
			continue
		}

		var identity security.Identity
		data, err := storage.ReadFile(st, path.Join(IdentitiesFolder, userId))
		if core.IsErr(err, nil, "cannot read identity file '%s/%s': %v", userId, err) {
			continue
		}

		userId, err = security.Unmarshal(data, &identity, "sg")
		if core.IsErr(err, nil, "cannot parse identity file '%s': %v", l.Name()) {
			continue
		}
		if userId != identity.Id {
			core.IsErr(ErrSignatureMismatch, nil, "file '%s' is signed with wrong identity: %v", l.Name())
			continue
		}

		err = security.SetIdentity(identity)
		if core.IsErr(err, nil, "cannot parse identity file '%s': %v", l.Name()) {
			continue
		}
		identities = append(identities, identity)
		core.Info("identity '%s' has been updated", userId)
	}

	return identities, nil
}
