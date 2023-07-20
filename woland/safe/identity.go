package safe

import (
	"fmt"
	"path"

	"github.com/stregato/masterwoland/core"
	"github.com/stregato/masterwoland/security"
	"github.com/stregato/masterwoland/storage"
)

var ErrSignatureMismatch = fmt.Errorf("provided signature does not match the expected identity")

// writeIdentity writes an identity to a store and update the DB
func writeIdentity(st storage.Store, self security.Identity) error {
	data, err := security.Marshal(self, self.Public(), "sg")
	if core.IsErr(err, "cannot marshal identity %s: %v", self.ID()) {
		return err
	}
	err = storage.WriteFile(st, path.Join(UsersFolder, self.ID(), UserFile), data)
	if core.IsErr(err, "cannot write identity %s: %v", self.ID()) {
		return err
	}
	security.SetIdentity(self)
	return nil
}

// readIdentities read identities from a store and update the DB when required
func readIdentities(st storage.Store) (map[string]security.Identity, error) {
	identities, err := security.Identities()
	if core.IsErr(err, "cannot read identitied from DB: %v") {
		return nil, err
	}

	m := map[string]*security.Identity{}
	for _, i := range identities {
		m[i.ID()] = &i
	}

	ls, err := st.ReadDir(UsersFolder, storage.Filter{})
	if core.IsErr(err, "cannot list identity files': %v", err) {
		return nil, err
	}

	m2 := map[string]security.Identity{}
	for _, l := range ls {
		if !l.IsDir() {
			continue
		}

		userId := l.Name()
		l, err = st.Stat(path.Join(UsersFolder, userId, UserFile))
		if core.IsErr(err, "cannot stat identity file '%s': %v", userId, err) {
			continue
		}

		if identity, ok := m[userId]; ok && identity.ModTime.Before(l.ModTime()) {
			m2[userId] = *identity
			continue
		}

		var identity security.Identity
		data, err := storage.ReadFile(st, path.Join(UsersFolder, userId, UserFile))
		if core.IsErr(err, "cannot read identity file '%s/%s': %v", userId, UserFile, err) {
			continue
		}

		userId, err = security.Unmarshal(data, &identity, "sg")
		if core.IsErr(err, "cannot parse identity file '%s': %v", l.Name()) {
			continue
		}
		if userId != identity.ID() {
			core.IsErr(ErrSignatureMismatch, "file '%s' is signed with wrong identity: %v", l.Name())
		}

		err = security.SetIdentity(identity)
		if core.IsErr(err, "cannot parse identity file '%s': %v", l.Name()) {
			continue
		}
		m2[l.Name()] = identity
	}

	return m2, nil
}
