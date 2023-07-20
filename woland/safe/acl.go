package safe

import (
	"golang.org/x/crypto/blake2b"

	"github.com/stregato/masterwoland/core"
	"github.com/stregato/masterwoland/security"
	"github.com/stregato/masterwoland/storage"
)

// ACL represents the access control list for a zone, which includes a map associating
// user IDs with corresponding user information, a trail of permission changes,
// the user ID of the entity who signed the user information, and the cryptographic signature
// of the hash of the user information.
type ACL struct {
	KeyId           uint64             `json:"keyId" yaml:"keyId"`
	KeyValues       map[string][]byte  `json:"keyValues" yaml:"keyValues"`
	PermissionChain []PermissionChange `json:"permissions" yaml:"permissions"`
}

type ACLSignature struct {
	SignedBy  string `json:"signedBy" yaml:"signedBy"`
	Signature []byte `json:"signature" yaml:"signature"`
}

func createACL(permissionChain []PermissionChange, keystore uint64, keystoreKey []byte) (ACL, error) {
	acl := ACL{
		KeyId:           keystore,
		KeyValues:       map[string][]byte{},
		PermissionChain: permissionChain,
	}

	permissions, _ := getUsers("", acl.PermissionChain)
	for userId, permission := range permissions {
		if permission&PermissionUser != 0 {
			key, err := security.EcEncrypt(userId, keystoreKey)
			if core.IsErr(err, "cannot encrypt master key for user %s: %v", userId, err) {
				return acl, err
			}

			acl.KeyValues[userId] = key
		}
	}
	return acl, nil
}

// readACL
func readACL(currentUser security.Identity, store storage.Store, filename string, rootId string) (ACL, error) {
	var acl ACL

	var signature ACLSignature
	signatureFilename := filename + ".sig"
	err := storage.ReadJSON(store, signatureFilename, &signature, nil)
	if core.IsErr(err, "cannot read ACL signature from %s: %v", filename, err) {
		return acl, err
	}

	hash, _ := blake2b.New384(nil)
	err = storage.ReadJSON(store, filename, &acl, hash)
	if core.IsErr(err, "cannot read ACL %s: %v", filename, err) {
		return acl, err
	}

	permissions, _ := getUsers(rootId, acl.PermissionChain)
	validSignature := security.Verify(signature.SignedBy, hash.Sum(nil), signature.Signature)
	if permissions[signature.SignedBy]&PermissionAdmin == 0 || !validSignature {
		return acl, ErrInvalidACL
	}

	masterKey := extractKeyValueFromACL(currentUser, acl.KeyValues)
	if masterKey == nil {
		return acl, nil
	}

	return acl, nil
}

func writeACL(currentUser security.Identity, store storage.Store, filename string, acl ACL) error {
	hash, _ := blake2b.New384(nil)
	err := storage.WriteJSON(store, filename, acl, hash)
	if core.IsErr(err, "cannot write ACL: %v", err) {
		return err
	}

	signature, err := security.Sign(currentUser, hash.Sum(nil))
	if core.IsErr(err, "cannot sign ACL: %v", err) {
		return err
	}
	aclSignature := ACLSignature{
		SignedBy:  currentUser.ID(),
		Signature: signature,
	}

	signatureFilename := filename + ".sig"
	err = storage.WriteJSON(store, signatureFilename, aclSignature, nil)
	if core.IsErr(err, "cannot write ACL signature: %v", err) {
		return err
	}

	return nil
}

// isValidPermissionChange calculates the hash of a permission change and verifies the signature
func isValidPermissionChange(change PermissionChange) bool {
	hash := hashPermissionChange(change)
	return security.Verify(change.By, hash[:], change.Signature)
}

func extractKeyValueFromACL(currentUser security.Identity, keys map[string][]byte) []byte {
	currentUserId := currentUser.ID()
	for userId, key := range keys {
		if userId != currentUserId {
			continue
		}

		keystoreKey, err := security.EcDecrypt(currentUser, key)
		if core.IsErr(err, "cannot decrypt master key: %v", err) {
			return nil
		}

		return keystoreKey
	}
	return nil
}
