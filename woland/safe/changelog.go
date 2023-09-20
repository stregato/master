package safe

import (
	"encoding/json"
	"fmt"
	"path"
	"sort"
	"time"

	"github.com/godruoyi/go-snowflake"
	"golang.org/x/crypto/blake2b"

	"github.com/stregato/master/woland/core"
	"github.com/stregato/master/woland/security"
	"github.com/stregato/master/woland/storage"
)

type ChangeLog struct {
	Changes []Change `json:"changes"`
}

type ChangeType string

const (
	ChangePermission ChangeType = "permission"
	ChangeReplicas   ChangeType = "replicas"
)

type Change struct {
	Type      ChangeType `json:"type"`
	By        string     `json:"by"`
	What      []byte     `json:"what"`
	ModTime   time.Time  `json:"modTime"`
	Signature []byte     `json:"signature"`
}

type Permission int

const (
	PermissionNone       Permission = 0
	PermissionWait       Permission = 1
	PermissionRead       Permission = 2
	PermissionWrite      Permission = 4
	PermissionAdmin      Permission = 16
	PermissionSuperAdmin Permission = 32
)

type Users map[string]Permission

type PermissionChange struct {
	UserId     string     `json:"userId"`
	Permission Permission `json:"permission"`
}

func hashOfChange(change Change) []byte {
	hash, _ := blake2b.New384(nil)
	hash.Write([]byte(change.Type))
	hash.Write([]byte(change.By))
	hash.Write(change.ModTime.UTC().AppendFormat(nil, time.RFC3339Nano))
	return hash.Sum(nil)
}

func isSignatureValid(change Change) bool {
	hash := hashOfChange(change)
	return security.Verify(change.By, hash, change.Signature)
}

func readChangeLogs(s storage.Store, safeName string, currentUser security.Identity,
	creatorId string, afterName string) (users Users, newestChangeFile string, err error) {

	files, err := s.ReadDir(ConfigFolder, storage.Filter{Suffix: ".change", AfterName: afterName})
	if core.IsErr(err, nil, "cannot read change log files: %v", err) {
		return nil, "", err
	}

	users = Users{creatorId: PermissionRead + PermissionWrite + PermissionAdmin + PermissionSuperAdmin}
	for _, file := range files {
		var changeLog ChangeLog
		name := file.Name()
		if name > newestChangeFile {
			newestChangeFile = name
		}

		data, err := storage.ReadFile(s, path.Join(ConfigFolder, name))
		if err != nil {
			continue
		}

		signedBy, err := security.Unmarshal(data, &changeLog, "signature")
		if core.IsErr(err, nil, "cannot unmarshal change log: %v", err) {
			continue
		}

		var changes = changeLog.Changes
		sort.Slice(changes, func(i, j int) bool {
			return changes[i].ModTime.Before(changes[j].ModTime)
		})

		for _, change := range changes {
			if !isSignatureValid(change) {
				continue
			}

			if change.Type == ChangePermission {
				if users[change.By]&PermissionAdmin == 0 {
					continue
				}

				var permissionChange PermissionChange
				err := json.Unmarshal(change.What, &permissionChange)
				if core.IsErr(err, nil, "cannot unmarshal permission change: %v", err) {
					continue
				}
				users[permissionChange.UserId] = permissionChange.Permission
			}
		}

		if users[signedBy]&PermissionAdmin == 0 {
			return nil, "", fmt.Errorf("invalid change log file: not signed by administrator")
		}
	}

	return users, newestChangeFile, nil
}

func writePermissionChange(s storage.Store, safeName string, currentUser security.Identity, users Users) error {
	var changeLog ChangeLog

	for userId, permission := range users {
		change := Change{
			Type:    ChangePermission,
			By:      currentUser.Id,
			ModTime: core.Now(),
		}

		permissionChange := PermissionChange{
			UserId:     userId,
			Permission: permission,
		}

		data, err := json.Marshal(permissionChange)
		if core.IsErr(err, nil, "cannot marshal permission change: %v", err) {
			return err
		}
		change.What = data

		hash := hashOfChange(change)
		signature, err := security.Sign(currentUser, hash)
		if core.IsErr(err, nil, "cannot sign permission change: %v", err) {
			return err
		}
		change.Signature = signature

		changeLog.Changes = append(changeLog.Changes, change)
	}

	data, err := security.Marshal(currentUser, changeLog, "signature")
	if core.IsErr(err, nil, "cannot marshal change log: %v", err) {
		return err
	}
	name := fmt.Sprintf("%d.change", snowflake.ID())
	err = storage.WriteFile(s, path.Join(ConfigFolder, name), data)
	if core.IsErr(err, nil, "cannot write change log '%s': %v", name, err) {
		return err
	}
	return nil
}
