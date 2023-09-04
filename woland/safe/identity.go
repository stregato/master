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
	err = storage.WriteFile(st, path.Join(UsersFolder, self.Id, UserFile), data)
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

	m := map[string]*security.Identity{}
	for _, i := range dbIdentities {
		m[i.Id] = &i
	}

	ls, err := st.ReadDir(UsersFolder, storage.Filter{})
	if !os.IsNotExist(err) && core.IsErr(err, nil, "cannot list identity files': %v", err) {
		return nil, err
	}

	var identities []security.Identity
	for _, l := range ls {
		if !l.IsDir() {
			continue
		}

		userId := l.Name()
		l, err = st.Stat(path.Join(UsersFolder, userId, UserFile))
		if os.IsNotExist(err) || core.IsErr(err, nil, "cannot stat identity file '%s': %v", userId, err) {
			continue
		}

		if identity, ok := m[userId]; ok && identity.ModTime.Before(l.ModTime()) {
			identities = append(identities, *identity)
			continue
		}

		var identity security.Identity
		data, err := storage.ReadFile(st, path.Join(UsersFolder, userId, UserFile))
		if core.IsErr(err, nil, "cannot read identity file '%s/%s': %v", userId, UserFile, err) {
			continue
		}

		userId, err = security.Unmarshal(data, &identity, "sg")
		if core.IsErr(err, nil, "cannot parse identity file '%s': %v", l.Name()) {
			continue
		}
		if userId != identity.Id {
			core.IsErr(ErrSignatureMismatch, nil, "file '%s' is signed with wrong identity: %v", l.Name())
		}

		err = security.SetIdentity(identity)
		if core.IsErr(err, nil, "cannot parse identity file '%s': %v", l.Name()) {
			continue
		}
		identities = append(identities, identity)
	}

	return identities, nil
}
