package safe

import (
	"encoding/json"
	"fmt"
	"path"

	"github.com/godruoyi/go-snowflake"

	"github.com/stregato/master/woland/core"
	"github.com/stregato/master/woland/security"
	"github.com/stregato/master/woland/sql"
	"github.com/stregato/master/woland/storage"
)

type Keystore struct {
	LastKeyId uint64            `json:"lastKeyId"`
	Keys      map[uint64][]byte `json:"keys"`
}

// syncKeystore reads all keystore files in the given store and returns the keyId and key for the largest keyId, all
// the keys and the delta of users that have been added or removed for the last keyId.
func syncKeystore(s storage.Store, safeName string, currentUser security.Identity,
	users map[string]Permission) (keystore Keystore, withKeys map[string]bool, err error) {

	files, err := s.ReadDir(path.Join(safeName, ConfigFolder), storage.Filter{Suffix: ".keystore"})
	if core.IsErr(err, nil, "cannot read keystore files: %v", err) {
		return Keystore{}, nil, err
	}

	var lastKeyId uint64
	keys := make(map[uint64][]byte)

	for _, file := range files {
		name := path.Join(safeName, ConfigFolder, file.Name())
		keyId2, key2, withKeys2, signedBy, err := readKeystoreFile(s, safeName, name, currentUser)
		if core.IsErr(err, nil, "cannot read keystore file: %v", err) {
			continue
		}
		if keyId2 == 0 {
			continue
		}

		keys[keyId2] = key2

		if keyId2 > lastKeyId && users[signedBy] >= Admin {
			lastKeyId = keyId2
			withKeys = withKeys2
			core.Info("found newer key with id %d signed by %s", lastKeyId, signedBy)
		} else if keyId2 == lastKeyId {
			for userId := range withKeys {
				withKeys[userId] = withKeys[userId] || withKeys2[userId]
			}
		}
	}
	keystore.LastKeyId = lastKeyId
	keystore.Keys = keys
	writeKeyStoreToDB(safeName, keystore)

	core.Info("keystores read: name %s, keyId %d, withKeys %v", safeName, keystore.LastKeyId, withKeys)
	return keystore, withKeys, nil
}

func readKeystoreFile(s storage.Store, safeName string, path string, currentUser security.Identity) (keyId uint64,
	key []byte, users map[string]bool, signedBy string, err error) {
	var keystoreFile KeystoreFile

	data, err := storage.ReadFile(s, path)
	if core.IsErr(err, nil, "cannot read keystore file: %v", err) {
		return 0, nil, nil, "", err
	}

	signedBy, err = security.Unmarshal(data, &keystoreFile, "signature")
	if core.IsErr(err, nil, "cannot read keystore file: %v", err) {
		return 0, nil, nil, "", err
	}

	encryptedKey, ok := keystoreFile.Keys[currentUser.Id]
	if !ok {
		core.Info("keystore read: name %s does not contain key for %s", safeName, currentUser.Id)
		return 0, nil, nil, "", nil
	}

	key, err = security.EcDecrypt(currentUser, encryptedKey)
	if core.IsErr(err, nil, "cannot decrypt primary key: %v", err) {
		return 0, nil, nil, "", err
	}

	users = make(map[string]bool)
	for userId := range keystoreFile.Keys {
		users[userId] = true
	}

	core.Info("keystore read: name %s, keyId %d, signedBy %s", safeName, keystoreFile.KeyId, signedBy)

	return keystoreFile.KeyId, key, users, signedBy, nil
}

func writeKeyStoreFile(s storage.Store, safeName string, currentUser security.Identity, keystore Keystore,
	users Users) error {
	keystoreFile := KeystoreFile{
		KeyId: keystore.LastKeyId,
		Keys:  make(map[string][]byte),
	}

	for userId, permission := range users {
		if permission > Suspended {
			encryptedKey, err := security.EcEncrypt(userId, keystore.Keys[keystore.LastKeyId])
			if core.IsErr(err, nil, "cannot encrypt primary key: %v", err) {
				return err
			}
			keystoreFile.Keys[userId] = encryptedKey
		}
	}

	data, err := security.Marshal(currentUser, keystoreFile, "signature")
	if core.IsErr(err, nil, "cannot marshal keystore: %v", err) {
		return err
	}

	name := fmt.Sprintf("%d.keystore", snowflake.ID())
	err = storage.WriteFile(s, path.Join(safeName, ConfigFolder, name), data)
	if core.IsErr(err, nil, "cannot write keystore: %v", err) {
		return err
	}
	core.Info("keystore %s written in %s, keyId %d, #users %d", name, safeName, keystore.LastKeyId, len(keystoreFile.Keys))

	return nil
}

func writeKeyStoreToDB(safeName string, keystore Keystore) error {
	data, err := json.Marshal(keystore)
	if core.IsErr(err, nil, "cannot marshal keystore: %v", err) {
		return err
	}

	err = sql.SetConfig(safeName, "keystore", "", 0, data)
	if core.IsErr(err, nil, "cannot write keystore to db: %v", err) {
		return err
	}

	return nil
}

func readKeystoreFromDB(safeName string) Keystore {
	keystore := Keystore{
		Keys: make(map[uint64][]byte),
	}

	_, _, data, ok := sql.GetConfig(safeName, "keystore")
	if !ok {
		return keystore
	}

	err := json.Unmarshal(data, &keystore)
	if core.IsErr(err, nil, "cannot unmarshal keystore: %v", err) {
		return keystore
	}

	return keystore
}
