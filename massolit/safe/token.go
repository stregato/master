package safe

import (
	"bytes"
	"compress/gzip"
	"encoding/json"
	"fmt"
	"io"

	"github.com/stregato/master/massolit/core"
	"github.com/stregato/master/massolit/security"
)

type _token struct {
	Name      string   `json:"n"`
	CreatorId string   `json:"c"`
	Key       []byte   `json:"k,omitempty"`
	Urls      []string `json:"u"`
}

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
	}
	return core.Encode(data), nil
}

func DecodeAccess(identity security.Identity, access string) (name string, creatorId string, aesKey []byte, urls []string, err error) {
	if identity.Private == "" {
		return "", "", nil, nil,
			fmt.Errorf("cannot decode access token: no private key available for %s", identity.ID)
	}

	data, err := core.Decode(access)
	if core.IsErr(err, nil, "cannot decode access token: %v") {
		return "", "", nil, nil, err
	}

	data2, err := security.EcDecrypt(identity, data)
	if err == nil {
		data = data2
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
