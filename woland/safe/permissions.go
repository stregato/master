package safe

import (
	"sort"
	"time"

	"golang.org/x/crypto/blake2b"

	"github.com/stregato/masterwoland/core"
	"github.com/stregato/masterwoland/security"
)

// PermissionChange represents a change in permission, including the user involved,
// the type of permission, the modification time,
// the user making the change, and the associated cryptographic signature.
type PermissionChange struct {
	Origin    []byte                `json:"origin" yaml:"origin"`
	Users     map[string]Permission `json:"users" yaml:"users"`
	ModTime   time.Time             `json:"modTime" yaml:"modTime"`
	By        string                `json:"by" yaml:"by"`
	Signature []byte                `json:"signature" yaml:"signature"`
}

func createPermissionChange(origin *PermissionChange, currentUser security.Identity, users Users) (PermissionChange, error) {
	var originHash []byte
	if origin != nil {
		originHash = hashPermissionChange(*origin)
	}

	change := PermissionChange{
		Origin:  originHash,
		Users:   users,
		ModTime: time.Now(),
		By:      currentUser.ID(),
	}

	hash := hashPermissionChange(change)
	signature, err := security.Sign(currentUser, hash)
	if core.IsErr(err, "cannot sign permission change: %v", err) {
		return PermissionChange{}, err
	}
	change.Signature = signature
	return change, nil
}

func hashPermissionChange(change PermissionChange) []byte {
	hash, _ := blake2b.New384(nil)
	for userId, permission := range change.Users {
		hash.Write([]byte(userId))
		hash.Write([]byte{byte(permission)})
	}
	hash.Write([]byte(change.By))
	hash.Write(change.ModTime.UTC().AppendFormat(nil, time.RFC3339Nano))
	return hash.Sum(nil)
}

func getUsers(rootId string, trail []PermissionChange) (users Users, clearTrail []PermissionChange) {
	sort.Slice(trail, func(i, j int) bool {
		return trail[i].ModTime.Before(trail[j].ModTime)
	})

	users = map[string]Permission{rootId: PermissionAdmin}
	for _, change := range trail {
		valid := isValidPermissionChange(change)
		if valid && users[change.By]&PermissionAdmin == 1 {
			for userId, permission := range change.Users {
				users[userId] = permission
			}
			clearTrail = append(clearTrail, change)
		}
	}

	return users, clearTrail
}
