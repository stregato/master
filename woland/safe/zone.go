package safe

import (
	"encoding/json"
	"fmt"
	"os"
	"path"
	"strings"
	"time"

	"golang.org/x/exp/slices"

	"github.com/stregato/master/massolit/core"
	"github.com/stregato/master/massolit/security"
	"github.com/stregato/master/massolit/sql"
	"github.com/stregato/master/massolit/storage"
)

const (
	ACLSuffix  = ".acl"
	KeysSuffix = ".keys"
	KeySize    = 32
	zonesDir   = "zones"
)

var ErrInvalidACL = fmt.Errorf("invalid ACL")

type Permission2 int

const (
	PermissionUser Permission2 = 1 << iota
	PermissionAdmin2
)

// User represents the information associated with a user, including the encrypted master key,
// the last modification time, and the expiration time.
type User struct {
	MasterKey []byte    `json:"masterKey" yaml:"masterKey"`
	ModTime   time.Time `json:"modTime" yaml:"modTime"`
	Expires   time.Time `json:"expires" yaml:"expires"`
}

// Zone represents a zone, including the last modification time, the access control list (ACL),
// the ID of the default key for the zone, and a map associating key IDs with corresponding keys.
type Zone struct {
	CreatorId       string                 `json:"creatorId" yaml:"creatorId"`
	NameSignature   []byte                 `json:"nameSignature" yaml:"nameSignature"`
	Users           map[string]Permission2 `json:"users" yaml:"users"`
	PermissionChain []PermissionChange     `json:"permissionTrail" yaml:"permissionTrail"`
	AclFiles        []string               `json:"acls" yaml:"acls"`

	KeyId    uint64            `json:"keystoreId" yaml:"keystoreId"`
	KeyValue []byte            `json:"keystoreKey" yaml:"keystoreKey"`
	Keys     map[uint64][]byte `json:"keys" yaml:"keys"`

	requireNewKey bool
}

func (s *Safe) ListZones() ([]string, error) {
	var zones []string
	for z := range s.zones {
		zones = append(zones, z)
	}
	return zones, nil
}

func (s *Safe) AddZone(zoneName string, creatorId string) error {
	if _, ok := s.zones[zoneName]; ok {
		return nil
	}

	_, err := s.store.Stat(path.Join(zonesDir, zoneName))
	if os.IsNotExist(err) {
		return fmt.Errorf(ErrZoneNotExist, zoneName)
	} else if core.IsErr(err, nil, "cannot stat zone %s: %v", zoneName, err) {
		return err
	}

	zone := Zone{
		CreatorId: creatorId,
		Keys:      make(map[uint64][]byte),
	}
	err = syncZone(s.CurrentUser, s.store, s.Name, zoneName, &zone)
	if core.IsErr(err, nil, "cannot sync zone %s: %v", zoneName, err) {
		return err
	}

	err = setZoneToDB(s.Name, zoneName, zone)
	if core.IsErr(err, nil, "cannot write zone to DB: %v", err) {
		return err
	}

	s.zones[zoneName] = &zone
	return nil
}

func (s *Safe) CreateZone(zoneName string, users Users) error {
	_, err := s.store.Stat(path.Join(zonesDir, zoneName))
	if err == nil {
		return fmt.Errorf(ErrZoneExist, zoneName)
	}

	if users == nil {
		users = Users{}
	}

	nameSignature, err := security.Sign(s.CurrentUser, []byte(zoneName))
	if core.IsErr(err, nil, "cannot sign zone name: %v", err) {
		return err
	}

	keyId, keyValue := core.NextID(0), core.GenerateRandomBytes(KeySize)
	zone := Zone{
		CreatorId:     s.CurrentUser.ID,
		NameSignature: nameSignature,
		KeyId:         keyId,
		KeyValue:      keyValue,
		Keys:          map[uint64][]byte{keyId: keyValue},
	}
	s.zones[zoneName] = &zone

	users[s.CurrentUser.ID] = PermissionAdmin2 | PermissionUser
	setUsers(s.CurrentUser, s.store, s.Name, zoneName, users, &zone)

	return nil
}

func syncZone(currentUser security.Identity, store storage.Store, portalName string, zoneName string,
	zone *Zone) error {

	dir := path.Join(zonesDir, zoneName)
	ls, err := store.ReadDir(dir, storage.Filter{Suffix: ACLSuffix})
	if !os.IsNotExist(err) && core.IsErr(err, nil, "cannot list ACLs in %s: %v", dir, err) {
		return err
	}

	var aclFiles []string
	for _, l := range ls {
		aclFiles = append(aclFiles, l.Name())
	}

	//	var keyId uint64
	// var usersWithLastKey []string

	permissionChain := []PermissionChange{}
	for _, file := range aclFiles {
		if slices.Contains(zone.AclFiles, file) {
			continue
		}
		acl, err := readACL(currentUser, store, path.Join(dir, file))
		if core.IsErr(err, nil, "cannot read ACL %s: %v", file, err) {
			continue
		}
		// if keyId > acl.KeyId {
		// 	keyId = acl.KeyId
		// 	usersWithLastKey = nil
		// }

		permissionChain = append(permissionChain, acl.PermissionChain...)
		keyValue := extractKeyValueFromACL(currentUser, acl.KeyValues)
		if keyValue != nil {
			zone.Keys[acl.KeyId] = keyValue
		}
		if acl.KeyId > zone.KeyId {
			zone.KeyId = acl.KeyId
			zone.KeyValue = keyValue
		}

		// for userId := range acl.KeyValues {
		// 	usersWithLastKey = append(usersWithLastKey, userId)
		// }
	}

	zone.Users, zone.PermissionChain = getUsers(zone.CreatorId, permissionChain)
	zone.AclFiles = aclFiles

	// if zone.Users[currentUser.ID]&PermissionUser == 0 {
	// 	return ErrZoneNoAuth
	// }
	// zone.requireNewKey = anyWrongOrMissingKeyAssignement(usersWithLastKey, zone.Users)
	// zone.KeyId = keyId
	// zone.KeyValue = zone.Keys[keyId]

	return nil
}

func anyWrongOrMissingKeyAssignement(usersWithKey []string, users Users) bool {
	s := strings.Join(usersWithKey, " ")
	for userId, permission := range users {
		shouldHaveKey := permission&PermissionUser == 1
		if shouldHaveKey != strings.Contains(s, userId) {
			return true
		}
	}

	return false
}

func writeZone(currentUser security.Identity, store storage.Store, portalName string, zoneName string,
	zone *Zone) error {

	keyId := core.NextID(zone.KeyId)
	keyValue := core.GenerateRandomBytes(KeySize)
	zone.Keys[keyId] = keyValue

	dir := path.Join(zonesDir, zoneName)
	name := fmt.Sprintf("%d%s", keyId, ACLSuffix)
	aclFile := path.Join(dir, name)

	acl, err := createACL(zone.CreatorId, zone.PermissionChain, keyId, keyValue)
	if core.IsErr(err, nil, "cannot create ACL: %v", err) {
		return err
	}

	err = writeACL(currentUser, store, aclFile, acl)
	if core.IsErr(err, nil, "cannot write ACL: %v", err) {
		return err
	}

	for _, file := range zone.AclFiles {
		store.Delete(path.Join(dir, file))
		keyName := strings.TrimSuffix(file, ACLSuffix) + KeysSuffix
		store.Delete(path.Join(dir, keyName))
	}

	zone.KeyId = keyId
	zone.KeyValue = keyValue
	zone.requireNewKey = false
	zone.AclFiles = []string{name}

	return nil
}

func getZonesFromDB(portal string) (map[string]*Zone, error) {
	rows, err := sql.Query("GET_ZONES", sql.Args{"portal": portal})
	if core.IsErr(err, nil, "cannot read zones from DB: %v", err) {
		return nil, err
	}

	zones := map[string]*Zone{}
	for rows.Next() {
		var name string
		var value []byte
		err := rows.Scan(&name, &value)
		if core.IsErr(err, nil, "cannot read zone from DB: %v", err) {
			continue
		}

		var zone Zone
		err = json.Unmarshal(value, &zone)
		if core.IsErr(err, nil, "cannot unmarshal zone from DB: %v", err) {
			continue
		}

		zones[name] = &zone
	}
	return zones, nil
}

func setZoneToDB(portal string, name string, zone Zone) error {
	// Convert zone to JSON
	value, err := json.Marshal(zone)
	if err != nil {
		return err
	}

	_, err = sql.Exec("SET_ZONE", sql.Args{"portal": portal, "name": name, "value": value})
	if core.IsErr(err, nil, "cannot write acl to DB: %v", err) {
		return err
	}

	return nil
}

func deleteZoneFromDB(portal string, name string) error {
	_, err := sql.Exec("DELETE_ZONE", sql.Args{"portal": portal, "name": name})
	if core.IsErr(err, nil, "cannot delete zone from DB: %v", err) {
		return err
	}
	return nil
}

func readZones(currentUser security.Identity, store storage.Store, portalName string) (map[string]*Zone, error) {
	zones, err := getZonesFromDB(portalName)
	if core.IsErr(err, nil, "cannot read zones in %s: %v", portalName) {
		return nil, err
	}
	for zoneId, zone := range zones {
		err = syncZone(currentUser, store, portalName, zoneId, zone)
		if core.ErrLike(err, ErrNoAuth) {
			delete(zones, zoneId)
			store.Delete(path.Join(UsersFolder, currentUser.ID, zonesDir, zoneId))
			continue
		}
		if len(zone.AclFiles) > MaxACLFilesInZone {
			err = writeZone(currentUser, store, portalName, zoneId, zone)
		}

		core.IsErr(err, nil, "cannot sync zone %s: %v", zoneId, err)
	}

	return zones, nil
}
