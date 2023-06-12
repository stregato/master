package safe

import (
	"fmt"
	"path"

	"github.com/code-to-go/woland/core"
	"github.com/code-to-go/woland/security"
	"github.com/code-to-go/woland/storage"
)

var ErrSignatureMismatch = fmt.Errorf("provided signature does not match the expected identity")

// writeIdentity writes an identity to a store and update the DB
func writeIdentity(st storage.Store, base string, self security.Identity) error {
	data, err := security.Marshal(self, self, "sg")
	if core.IsErr(err, "cannot marshal identity %s: %v", self.Id()) {
		return err
	}
	err = storage.WriteFile(st, path.Join(base, IdentitiesFolder, self.Id()), data)
	if core.IsErr(err, "cannot write identity %s: %v", self.Id()) {
		return err
	}
	security.SetIdentity(self)
	return nil
}

// readIdentities read available identities from a store and update the DB
func readIdentities(st storage.Store, base string) error {
	identities, err := security.Identities()
	if core.IsErr(err, "cannot read identitied from DB: %v") {
		return err
	}

	m := map[string]*security.Identity{}
	for _, i := range identities {
		m[i.Id()] = &i
	}

	ls, err := st.ReadDir(path.Join(base, IdentitiesFolder), storage.Filter{})
	if core.IsErr(err, "cannot list identity files': %v", err) {
		return err
	}
	for _, l := range ls {
		if identity, ok := m[l.Name()]; ok && identity.ModTime.Before(l.ModTime()) {
			continue
		}

		var identity security.Identity
		data, err := storage.ReadFile(st, path.Join(base, IdentitiesFolder, l.Name()))
		if core.IsErr(err, "cannot read identity file '%s': %v", l.Name(), err) {
			continue
		}

		id, err := security.Unmarshal(data, &identity, "sg")
		if core.IsErr(err, "cannot parse identity file '%s': %v", l.Name()) {
			continue
		}
		if id != identity.Id() {
			core.IsErr(ErrSignatureMismatch, "file '%s' is signed with wrong identity: %v", l.Name())
		}

		err = security.SetIdentity(identity)
		if core.IsErr(err, "cannot parse identity file '%s': %v", l.Name()) {
			continue
		}
	}

	return nil
}
