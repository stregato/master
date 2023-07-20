package safe

import (
	"path/filepath"
	"time"

	"github.com/stregato/master/woland/security"
	"github.com/stregato/master/woland/storage"
)

// userChange represents a change made by a user.
type userChange struct {
	KeyID      uint64    `yaml:"keyId"`      // KeyID represents the ID of the key.
	Key        []byte    `yaml:"key"`        // Key represents the user's key.
	DefineTime time.Time `yaml:"defineTime"` // DefineTime represents the time when the change was defined.
	StartTime  time.Time `yaml:"activeTime"` // ActiveTime represents the time when the change becomes active.
}

// GroupChange represents a change made to a group.
type GroupChange struct {
	Add    map[string]userChange // Add represents the users to be added to the group along with their respective changes.
	Remove map[string]userChange // Remove represents the users to be removed from the group along with their respective changes.
}

// MergeGroupChanges merges multiple GroupChange objects into a single GroupChange.
func MergeGroupChanges(store storage.Store, identity security.Identity, groupName string) (mergedGroupChange GroupChange, keys map[uint64][]byte, err error) {
	mergedGroupChange = GroupChange{
		Add:    make(map[string]userChange),
		Remove: make(map[string]userChange),
	}

	keys = make(map[uint64][]byte)
	selfId := identity.ID()

	// Read directory to get the list of files for the specified group
	fileInfos, err := store.ReadDir(groupName, storage.Filter{})
	if err != nil {
		return GroupChange{}, nil, err
	}

	for _, fileInfo := range fileInfos {
		filename := fileInfo.Name()
		filePath := filepath.Join(groupName, filename)

		groupChange := GroupChange{}
		err := storage.ReadYAML(store, filePath, &groupChange, nil)
		if err != nil {
			return GroupChange{}, nil, err
		}

		// Merge Add changes
		for userId, change := range groupChange.Add {
			existingChange, exists := mergedGroupChange.Add[userId]
			if !exists || change.DefineTime.After(existingChange.DefineTime) {
				mergedGroupChange.Add[userId] = userChange{
					DefineTime: change.DefineTime,
					StartTime:  change.StartTime,
				}
			}

			if userId == selfId {
				decryptedKey, err := security.EcDecrypt(identity, change.Key)
				if err != nil {
					continue
				}

				keys[change.KeyID] = decryptedKey
			}
		}

		// Merge Remove changes
		for userId, change := range groupChange.Remove {
			existingChange, exists := mergedGroupChange.Remove[userId]
			if !exists || change.DefineTime.After(existingChange.DefineTime) {
				mergedGroupChange.Remove[userId] = userChange{
					DefineTime: change.DefineTime,
					StartTime:  change.StartTime,
				}
			}
		}
	}

	return mergedGroupChange, keys, nil
}
