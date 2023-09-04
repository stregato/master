package safe

import (
	"fmt"
	"path"

	"github.com/godruoyi/go-snowflake"

	"github.com/stregato/master/woland/core"
	"github.com/stregato/master/woland/security"
	"github.com/stregato/master/woland/storage"
)

// readKeystores reads all keystore files in the given store and returns the keyId and key for the largest keyId, all
// the keys and the delta of users that have been added or removed for the last keyId.
func readKeystores(s storage.Store, safename string, currentUser security.Identity,
	users map[string]Permission) (keyId uint64, key []byte, keys map[uint64][]byte,
	delta map[string]Permission, err error) {

	files, err := s.ReadDir(ConfigFolder, storage.Filter{Suffix: ".keystore"})
	if core.IsErr(err, nil, "cannot read keystore files: %v", err) {
		return 0, nil, nil, nil, err
	}

	keys = make(map[uint64][]byte)
	var withKeys map[string]bool
	for _, file := range files {
		name := path.Join(ConfigFolder, file.Name())
		keyId2, key2, withKeys2, signedBy, err := readKeystore(s, safename, name, currentUser)
		if core.IsErr(err, nil, "cannot read keystore file: %v", err) {
			continue
		}
		keys[keyId2] = key2

		if keyId2 > keyId && users[signedBy] >= PermissionAdmin {
			keyId = keyId2
			key = key2
			withKeys = withKeys2
		} else if keyId2 == keyId {
			for userId := range withKeys {
				withKeys[userId] = withKeys[userId] || withKeys2[userId]
			}
		}
	}

	delta = make(map[string]Permission)
	for userId, permission := range users {
		if !withKeys[userId] {
			delta[userId] = permission
		}
	}
	for userId := range withKeys {
		if users[userId] == 0 {
			delta[userId] = PermissionNone
		}
	}

	return keyId, key, keys, delta, nil
}

func readKeystore(s storage.Store, safeName string, path string, currentUser security.Identity) (keyId uint64,
	key []byte, users map[string]bool, signedBy string, err error) {
	var keystore Keystore

	data, err := storage.ReadFile(s, path)
	if core.IsErr(err, nil, "cannot read keystore file: %v", err) {
		return 0, nil, nil, "", err
	}

	signedBy, err = security.Unmarshal(data, &keystore, "signature")
	if core.IsErr(err, nil, "cannot read keystore file: %v", err) {
		return 0, nil, nil, "", err
	}

	encryptedKey, ok := keystore.Keys[currentUser.Id]
	if !ok {
		return 0, nil, nil, "", fmt.Errorf("cannot find primary key for user %s", currentUser.Id)
	}

	key, err = security.EcDecrypt(currentUser, encryptedKey)
	if core.IsErr(err, nil, "cannot decrypt primary key: %v", err) {
		return 0, nil, nil, "", err
	}

	users = make(map[string]bool)
	for userId := range keystore.Keys {
		users[userId] = true
	}

	return keystore.KeyId, key, users, signedBy, nil
}

func writeKeyStore(s storage.Store, safeName string, currentUser security.Identity, keyId uint64, key []byte,
	users Users) error {
	keystore := Keystore{
		KeyId: keyId,
		Keys:  make(map[string][]byte),
	}

	for userId := range users {
		encryptedKey, err := security.EcEncrypt(userId, key)
		if core.IsErr(err, nil, "cannot encrypt primary key: %v", err) {
			return err
		}
		keystore.Keys[userId] = encryptedKey
	}

	data, err := security.Marshal(currentUser, keystore, "signature")
	if core.IsErr(err, nil, "cannot marshal keystore: %v", err) {
		return err
	}

	name := fmt.Sprintf("%d.keystore", snowflake.ID())
	err = storage.WriteFile(s, path.Join(ConfigFolder, name), data)
	if core.IsErr(err, nil, "cannot write keystore: %v", err) {
		return err
	}

	return nil
}
