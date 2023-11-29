package safe

import (
	"bytes"
	"compress/gzip"
	"encoding/json"
	"fmt"
	"io"

	"github.com/stregato/master/woland/core"
	"github.com/stregato/master/woland/security"
)

type _token struct {
	Name      string   `json:"n"`
	CreatorId string   `json:"c"`
	Key       []byte   `json:"k,omitempty"`
	Urls      []string `json:"u"`
}

const dateEncryptLayout = "Jan 2 15 UTC 2006                                 "

func EncodeAccess(userID string, name string, creatorId string, aesKey []byte, urls ...string) (string, error) {
	if len(aesKey) == 0 {
		aesKey = nil
	}

	data, err := json.Marshal(_token{
		name, creatorId, aesKey, urls,
	})
	if core.IsErr(err, nil, "cannot marshal access information: %v") {
		return "", err
	}

	var buf bytes.Buffer
	w := gzip.NewWriter(&buf)
	_, err = io.Copy(w, bytes.NewBufferString(string(data)))
	w.Close()
	if core.IsErr(err, nil, "cannot zip access information: %v") {
		return "", err
	}

	if len(userID) > 0 {
		data, err = security.EcEncrypt(userID, buf.Bytes())
		if core.IsErr(err, nil, "cannot encrypt access token for %s", userID) {
			return "", err
		}
	} else {
		key := []byte(core.Now().UTC().Format(dateEncryptLayout))[0:32]
		data, err = security.EncryptAES(buf.Bytes(), key)
		if core.IsErr(err, nil, "cannot encrypt access token for %s", userID) {
			return "", err
		}
	}
	return core.EncodeBinary(data), nil
}

func decryptData(identity security.Identity, data []byte) ([]byte, error) {
	data2, err := security.EcDecrypt(identity, data)
	if err == nil {
		return data2, nil
	}

	now := core.Now()
	key := []byte(now.UTC().Format(dateEncryptLayout))[0:32]
	return security.DecryptAES(data, key)
}

func DecodeAccess(identity security.Identity, access string) (name string, creatorId string, aesKey []byte, urls []string, err error) {
	if identity.Private == "" {
		return "", "", nil, nil,
			fmt.Errorf("cannot decode access token: no private key available for %s", identity.Id)
	}

	data, err := core.DecodeBinary(access)
	if core.IsErr(err, nil, "cannot decode access token: %v") {
		return "", "", nil, nil, err
	}

	data, err = decryptData(identity, data)
	if core.IsErr(err, nil, "cannot decrypt access token '%s': %v", access) {
		return "", "", nil, nil, err
	}

	r, err := gzip.NewReader(bytes.NewReader(data))
	if core.IsErr(err, nil, "cannot unzip access token '%s': %v", access) {
		return "", "", nil, nil, err
	}

	var buf bytes.Buffer
	_, err = io.Copy(&buf, r)
	r.Close()
	if core.IsErr(err, nil, "cannot unzip access token '%s': %v", access) {
		return "", "", nil, nil, err
	}

	var t _token
	err = json.Unmarshal(buf.Bytes(), &t)
	if core.IsErr(err, nil, "cannot unmarshal access token '%s': %v", access) {
		return "", "", nil, nil, err
	}

	return t.Name, t.CreatorId, t.Key, t.Urls, err
}
