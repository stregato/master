package safe

import (
	"golang.org/x/crypto/blake2b"

	"github.com/stregato/master/massolit/core"
	"github.com/stregato/master/massolit/security"
	"github.com/stregato/master/massolit/storage"
)

// ACL represents the access control list for a zone, which includes a map associating
// user IDs with corresponding user information, a trail of permission changes,
// the user ID of the entity who signed the user information, and the cryptographic signature
// of the hash of the user information.
type ACL struct {
	CreatorId       string             `json:"creatorId" yaml:"creatorId"`
	KeyId           uint64             `json:"keyId" yaml:"keyId"`
	KeyValues       map[string][]byte  `json:"keyValues" yaml:"keyValues"`
	PermissionChain []PermissionChange `json:"permissions" yaml:"permissions"`
}

type ACLSignature struct {
	SignedBy  string `json:"signedBy" yaml:"signedBy"`
	Signature []byte `json:"signature" yaml:"signature"`
}

func createACL(creatorId string, permissionChain []PermissionChange, keystore uint64, keystoreKey []byte) (ACL, error) {
	acl := ACL{
		CreatorId:       creatorId,
		KeyId:           keystore,
		KeyValues:       map[string][]byte{},
		PermissionChain: permissionChain,
	}

	permissions, _ := getUsers(creatorId, acl.PermissionChain)
	for userId, permission := range permissions {
		if permission&PermissionUser != 0 {
			key, err := security.EcEncrypt(userId, keystoreKey)
			if core.IsErr(err, nil, "cannot encrypt master key for user %s: %v", userId, err) {
				return acl, err
			}

			acl.KeyValues[userId] = key
		}
	}
	return acl, nil
}

// readACL
func readACL(currentUser security.Identity, store storage.Store, filename string) (ACL, error) {
	var acl ACL

	var signature ACLSignature
	signatureFilename := filename + ".sig"
	err := storage.ReadJSON(store, signatureFilename, &signature, nil)
	if core.IsErr(err, nil, "cannot read ACL signature from %s: %v", filename, err) {
		return acl, err
	}

	hash, _ := blake2b.New384(nil)
	err = storage.ReadJSON(store, filename, &acl, hash)
	if core.IsErr(err, nil, "cannot read ACL %s: %v", filename, err) {
		return acl, err
	}

	permissions, _ := getUsers(acl.CreatorId, acl.PermissionChain)
	validSignature := security.Verify(signature.SignedBy, hash.Sum(nil), signature.Signature)
	if permissions[signature.SignedBy]&PermissionAdmin2 == 0 || !validSignature {
		return acl, ErrInvalidACL
	}

	return acl, nil
}

func writeACL(currentUser security.Identity, store storage.Store, filename string, acl ACL) error {
	hash, _ := blake2b.New384(nil)
	err := storage.WriteJSON(store, filename, acl, hash)
	if core.IsErr(err, nil, "cannot write ACL: %v", err) {
		return err
	}

	signature, err := security.Sign(currentUser, hash.Sum(nil))
	if core.IsErr(err, nil, "cannot sign ACL: %v", err) {
		return err
	}
	aclSignature := ACLSignature{
		SignedBy:  currentUser.ID,
		Signature: signature,
	}

	signatureFilename := filename + ".sig"
	err = storage.WriteJSON(store, signatureFilename, aclSignature, nil)
	if core.IsErr(err, nil, "cannot write ACL signature: %v", err) {
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
	if key, ok := keys[currentUser.ID]; ok {
		keystoreKey, err := security.EcDecrypt(currentUser, key)
		if core.IsErr(err, nil, "cannot decrypt master key: %v", err) {
			return nil
		}
		return keystoreKey
	}

	return nil
}
