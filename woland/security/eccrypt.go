package security

import (
	eciesgo "github.com/ecies/go/v2"

	"github.com/stregato/master/woland/core"
)

func EcEncrypt(id string, data []byte) ([]byte, error) {
	cryptKey, _, err := DecodeKeys(id)
	if core.IsErr(err, nil, "cannot decode keys: %v") {
		return nil, err
	}

	pk, err := eciesgo.NewPublicKeyFromBytes(cryptKey)
	if core.IsErr(err, nil, "cannot convert bytes to secp256k1 public key: %v") {
		return nil, err
	}
	data, err = eciesgo.Encrypt(pk, data)
	if core.IsErr(err, nil, "cannot encrypt with secp256k1: %v") {
		return nil, err
	}
	return data, err
}

func EcDecrypt(identity Identity, data []byte) ([]byte, error) {
	cryptKey, _, err := DecodeKeys(identity.Private)
	if core.IsWarn(err, "cannot decode keys: %v") {
		return nil, err
	}

	data, err = eciesgo.Decrypt(eciesgo.NewPrivateKeyFromBytes(cryptKey), data)
	if core.IsWarn(err, "cannot decrypt with secp256k1: %v") {
		return nil, err
	}
	return data, nil
}
