package safe

import (
	"fmt"
	"path"

	"github.com/stregato/master/massolit/core"
	"github.com/stregato/master/massolit/security"
	"github.com/stregato/master/massolit/storage"
)

type Users map[string]Permission2

const (
	ErrZoneNotExist    = "zone '%s' does not exist"               // Returned when a zone does not exist
	ErrZoneNameTooLong = "zone name '%s' too long, max length 32" // Returned when a zone name is too long
	ErrZoneExist       = "zone '%s' already exists"               //
	ErrNoAuth          = "user '%s['%s']' has not authorization for box '%s'"
	ErrZoneNoAdmin     = "user '%s' has not admin rights for zone '%s'"
)

// SetUsers sets some users with corresponding permissions for a zone.
func (s *Safe) SetUsers(zoneName string, users Users) error {
	zone, ok := s.zones[zoneName]
	if !ok {
		return fmt.Errorf(ErrZoneNotExist, zoneName)
	}

	return setUsers(s.CurrentUser, s.store, s.Name, zoneName, users, zone)
}

func setUsers(currentUser security.Identity, store storage.Store, portalName string, zoneName string, users Users, zone *Zone) error {
	syncZone(currentUser, store, portalName, zoneName, zone)

	currentUserId := currentUser.ID
	if zone.Users[currentUserId]&PermissionAdmin2 == 0 {
		return fmt.Errorf(ErrZoneNoAdmin, currentUserId, zoneName)
	}

	var includesRevoke bool
	for _, permission := range users {
		includesRevoke = includesRevoke || permission&PermissionUser == 0
	}

	var lastChange *PermissionChange
	if len(zone.PermissionChain) > 0 {
		lastChange = &zone.PermissionChain[len(zone.PermissionChain)-1]
	}
	change, err := createPermissionChange(lastChange, currentUser, users)
	if core.IsErr(err, nil, "cannot create permission change: %v", err) {
		return err
	}
	zone.PermissionChain = append(zone.PermissionChain, change)

	aclName := fmt.Sprintf("%d%s", core.NextID(0), ACLSuffix)
	if !includesRevoke {
		acl, err := createACL(zone.CreatorId, []PermissionChange{change}, zone.KeyId, zone.KeyValue)
		if core.IsErr(err, nil, "cannot create ACL: %v", err) {
			return err
		}
		err = writeACL(currentUser, store, path.Join(zonesDir, zoneName, aclName), acl)
		if core.IsErr(err, nil, "cannot write ACL: %v", err) {
			return err
		}
	} else {
		zone.KeyId, zone.KeyValue = core.NextID(zone.KeyId), core.GenerateRandomBytes(32)
		acl, err := createACL(zone.CreatorId, zone.PermissionChain, zone.KeyId, zone.KeyValue)
		if core.IsErr(err, nil, "cannot create ACL: %v", err) {
			return err
		}
		err = writeACL(currentUser, store, path.Join(zonesDir, zoneName, aclName), acl)
		if core.IsErr(err, nil, "cannot write ACL: %v", err) {
			return err
		}

		for _, file := range zone.AclFiles {
			store.Delete(path.Join(zonesDir, zoneName, file))
		}
	}
	zone.AclFiles = append(zone.AclFiles, aclName)

	for userId, permission := range users {
		zone.Users[userId] = permission
		err = sendEvent(currentUser, store, userId, ZoneSubscription{
			CreatorID:     zone.CreatorId,
			ZoneName:      zoneName,
			NameSignature: zone.NameSignature,
		})
		core.IsErr(err, nil, "cannot send event: %v", err)
	}

	return setZoneToDB(portalName, zoneName, *zone)
}

func (s *Safe) GetUsers(zoneName string) (Users, error) {
	zone, ok := s.zones[zoneName]
	if !ok {
		return nil, fmt.Errorf(ErrZoneNotExist, zoneName)
	}

	return zone.Users, nil
}

func (s *Safe) GetIdentities() ([]security.Identity, error) {
	return s.identities, nil
}
