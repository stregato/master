package safe

import (
	"fmt"
	"path"

	"github.com/code-to-go/safepool/core"
)

var ErrGroupExist = fmt.Errorf("cannot create a group that already exists")

func (s *Safe) GetGroups() ([]string, error) {
	ls, err := s.store.ReadDir(path.Join(s.Name, DataFolder), 0)
	if core.IsErr(err, "cannot read groups in %s/%s: %v", s.store, s.Name) {
		return nil, err
	}

	var groups []string
	for _, l := range ls {
		groups = append(groups, l.Name())
	}
	return groups, nil
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
}
