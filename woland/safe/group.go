package safe

import (
	"fmt"
	"path"

	"github.com/code-to-go/woland/core"
	"github.com/code-to-go/woland/storage"
)

var ErrGroupExist = fmt.Errorf("cannot create a group that already exists")

func (s *Safe) loadGroups() error {
	ls, err := s.store.ReadDir(path.Join(s.Name, DataFolder), storage.Filter{})
	if core.IsErr(err, "cannot read groups in %s/%s: %v", s.store, s.Name) {
		return err
	}

	for _, l := range ls {
		s.groups = append(s.groups, l.Name())
	}
	return nil
}

func (s *Safe) createGroup(name string) (string, error) {
	err := s.loadGroups()
	if core.IsErr(err, "cannot create group: %v") {
		return "", err
	}

	if name == "" {

	}

	for _, g := range s.groups {
		if g == name {
			return "", ErrGroupExist
		}
	}
	return name, nil
}
