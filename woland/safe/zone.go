package safe

import (
	"encoding/json"
	"fmt"
	"os"
	"path"
	"sort"
	"strings"
	"time"

	"github.com/stregato/master/woland/core"
	"github.com/stregato/master/woland/security"
	"github.com/stregato/master/woland/sql"
	"github.com/stregato/master/woland/storage"
)

const (
	ACLSuffix  = ".acl"
	KeysSuffix = ".keys"
	KeySize    = 32
	zonesDir   = "zones"
)

var ErrInvalidACL = fmt.Errorf("invalid ACL")

type Permission int

const (
	PermissionUser Permission = 1 << iota
	PermissionAdmin
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
	RootId          string                `json:"rootId" yaml:"rootId"`
	Users           map[string]Permission `json:"users" yaml:"users"`
	PermissionChain []PermissionChange    `json:"permissionTrail" yaml:"permissionTrail"`
	Acls            []string              `json:"acls" yaml:"acls"`

	KeyId    uint64            `json:"keystoreId" yaml:"keystoreId"`
	KeyValue []byte            `json:"keystoreKey" yaml:"keystoreKey"`
	Keys     map[uint64][]byte `json:"keys" yaml:"keys"`

	requireNewKey bool
}

func (s *Safe) Zones() ([]string, error) {
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
		return ErrZoneNotExist
	} else if core.IsErr(err, "cannot stat zone %s: %v", zoneName, err) {
		return err
	}

	zone := Zone{
		RootId: creatorId,
		Keys:   make(map[uint64][]byte),
	}
	err = readZone(s.CurrentUser, s.store, s.Name, zoneName, &zone)
	if core.IsErr(err, "cannot sync zone %s: %v", zoneName, err) {
		return err
	}

	err = setZoneToDB(s.Name, zoneName, zone)
	if core.IsErr(err, "cannot write zone to DB: %v", err) {
		return err
	}

	s.zones[zoneName] = zone
	return nil
}

func (s *Safe) CreateZone(zoneName string, users Users) error {
	_, err := s.store.Stat(path.Join(zonesDir, zoneName))
	if err == nil {
		return ErrZoneExist
	}

	if users == nil {
		users = Users{}
	}

	users[s.CurrentUser.ID()] = PermissionAdmin | PermissionUser
	change, err := createPermissionChange(nil, s.CurrentUser, users)
	if core.IsErr(err, "cannot create permission change: %v", err) {
		return err
	}

	zone := Zone{
		RootId:          s.CurrentUser.ID(),
		Users:           users,
		PermissionChain: []PermissionChange{change},
		Keys:            map[uint64][]byte{},
	}

	err = writeZone(s.CurrentUser, s.store, s.Name, zoneName, &zone)
	if core.IsErr(err, "cannot sync zone %s: %v", zoneName, err) {
		return err
	}

	err = setZoneToDB(s.Name, zoneName, zone)
	if core.IsErr(err, "cannot write zone to DB: %v", err) {
		return err
	}

	s.zones[zoneName] = zone
	return nil
}

func readZone(currentUser security.Identity, store storage.Store, safeName string, zoneName string,
	zone *Zone) error {

	dir := path.Join(zonesDir, zoneName)
	ls, err := store.ReadDir(dir, storage.Filter{Suffix: ACLSuffix})
	if core.IsErr(err, "cannot list ACLs in %s: %v", dir, err) {
		return err
	}

	var aclFiles []string
	for _, l := range ls {
		aclFiles = append(aclFiles, l.Name())
	}
	sort.Strings(aclFiles)
	if strings.Join(aclFiles, " ") == strings.Join(zone.Acls, " ") {
		return nil
	}

	var keyId uint64
	var usersWithLastKey []string

	permissionChain := []PermissionChange{}
	for _, file := range aclFiles {
		acl, err := readACL(currentUser, store, path.Join(dir, file), zone.RootId)
		if core.IsErr(err, "cannot read ACL %s: %v", file, err) {
			continue
		}
		if keyId > acl.KeyId {
			keyId = acl.KeyId
			usersWithLastKey = nil
		}

		permissionChain = append(permissionChain, acl.PermissionChain...)
		keyValue := extractKeyValueFromACL(currentUser, acl.KeyValues)
		if keyValue != nil {
			zone.Keys[acl.KeyId] = keyValue
		}

		for userId := range acl.KeyValues {
			usersWithLastKey = append(usersWithLastKey, userId)
		}
	}

	zone.Users, zone.PermissionChain = getUsers(zone.RootId, permissionChain)
	zone.Acls = aclFiles

	if zone.Users[currentUser.ID()]&PermissionUser == 0 {
		return ErrZoneNoAuth
	}
	zone.requireNewKey = anyWrongOrMissingKeyAssignement(usersWithLastKey, zone.Users)
	zone.KeyId = keyId
	zone.KeyValue = zone.Keys[keyId]

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

func writeZone(currentUser security.Identity, store storage.Store, safeName string, zoneName string,
	zone *Zone) error {

	keyId := core.NextID(zone.KeyId)
	keyValue := core.GenerateRandomBytes(KeySize)
	zone.Keys[keyId] = keyValue

	dir := path.Join(zonesDir, zoneName)
	name := fmt.Sprintf("%d%s", keyId, ACLSuffix)
	aclFile := path.Join(dir, name)

	acl, err := createACL(zone.PermissionChain, keyId, keyValue)
	if core.IsErr(err, "cannot create ACL: %v", err) {
		return err
	}

	err = writeACL(currentUser, store, aclFile, acl)
	if core.IsErr(err, "cannot write ACL: %v", err) {
		return err
	}

	for _, file := range zone.Acls {
		store.Delete(path.Join(dir, file))
		keyName := strings.TrimSuffix(file, ACLSuffix) + KeysSuffix
		store.Delete(path.Join(dir, keyName))
	}

	zone.KeyId = keyId
	zone.KeyValue = keyValue
	zone.requireNewKey = false
	zone.Acls = []string{name}

	return nil
}

func getZonesFromDB(safe string) (map[string]Zone, error) {
	rows, err := sql.Query("GET_ZONES", sql.Args{"safe": safe})
	if core.IsErr(err, "cannot read zones from DB: %v", err) {
		return nil, err
	}

	zones := map[string]Zone{}
	for rows.Next() {
		var name string
		var value []byte
		err := rows.Scan(&name, &value)
		if core.IsErr(err, "cannot read zone from DB: %v", err) {
			continue
		}

		var zone Zone
		err = json.Unmarshal(value, &zone)
		if core.IsErr(err, "cannot unmarshal zone from DB: %v", err) {
			continue
		}

		zones[name] = zone
	}
	return zones, nil
}

func setZoneToDB(safe string, name string, zone Zone) error {
	// Convert zone to JSON
	value, err := json.Marshal(zone)
	if err != nil {
		return err
	}

	_, err = sql.Exec("SET_ZONE", sql.Args{"safe": safe, "name": name, "value": value})
	if core.IsErr(err, "cannot write acl to DB: %v", err) {
		return err
	}

	return nil
}

func deleteZoneFromDB(safe string, name string) error {
	_, err := sql.Exec("DELETE_ZONE", sql.Args{"safe": safe, "name": name})
	if core.IsErr(err, "cannot delete zone from DB: %v", err) {
		return err
	}
	return nil
}
