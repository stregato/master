package safe

import (
	"fmt"
	"path"

	"github.com/stregato/master/woland/core"
	"github.com/stregato/master/woland/security"
	"github.com/stregato/master/woland/storage"
)

type Users map[string]Permission

var ErrZoneNotExist = fmt.Errorf("zone does not exist")                                        // Returned when a zone does not exist
var ErrZoneExist = fmt.Errorf("zone already exists")                                           // Returned when a zone already exists
var ErrZoneNoAuth = fmt.Errorf("zone exists but user is not authorized")                       // Returned when a zone exists but the user is not authorized
var ErrZoneNoAdmin = fmt.Errorf("current user is not admin and operation cannot be performed") // Returned when the current user is not admin and the operation cannot be performed

// SetUsers sets some users with corresponding permissions for a zone.
func (s *Safe) SetUsers(zoneName string, users Users) error {
	zone, ok := s.zones[zoneName]
	if !ok {
		return ErrZoneNotExist
	}

	currentUserId := s.CurrentUser.ID()
	if zone.Users[currentUserId]&PermissionAdmin == 0 {
		return ErrZoneNoAdmin
	}

	for userId, permission := range users {
		zone.Users[userId] = permission
		if permission&PermissionUser == 0 {
			zone.requireNewKey = true
		}
	}
	lastChange := zone.PermissionChain[len(zone.PermissionChain)-1]
	change, err := createPermissionChange(&lastChange, s.CurrentUser, users)
	if core.IsErr(err, "cannot create permission change: %v", err) {
		return err
	}
	zone.PermissionChain = append(zone.PermissionChain, change)

	if zone.requireNewKey {
		return writeZone(s.CurrentUser, s.store, s.Name, zoneName, &zone)
	} else {
		return writeZoneAddition(s.CurrentUser, s.store, s.Name, zoneName, &zone)
	}
}

func writeZoneAddition(currentUser security.Identity, store storage.Store, safeName string, zoneName string, zone *Zone) error {
	acl, err := createACL(zone.PermissionChain, zone.KeyId, zone.KeyValue)
	if core.IsErr(err, "cannot create ACL: %v", err) {
		return err
	}

	name := fmt.Sprintf("%d%s", core.NextID(acl.KeyId), ACLSuffix)
	filename := path.Join(zonesDir, zoneName, name)
	err = writeACL(currentUser, store, filename, acl)
	if core.IsErr(err, "cannot write ACL: %v", err) {
		return err
	}

	zone.Acls = append(zone.Acls, name)
	err = setZoneToDB(safeName, zoneName, *zone)
	if core.IsErr(err, "cannot write zone to DB: %v", err) {
		return err
	}
	return nil
}

func (s *Safe) GetUsers(zoneName string) (Users, error) {
	zone, ok := s.zones[zoneName]
	if !ok {
		return nil, ErrZoneNotExist
	}

	return zone.Users, nil
}
