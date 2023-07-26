package portal

import (
	"bytes"
	"compress/gzip"
	"encoding/base64"
	"encoding/json"
	"fmt"
	"io"
	"strings"

	"github.com/stregato/master/woland/core"
	"github.com/stregato/master/woland/security"
)

type _token struct {
	Name string   `json:"n"`
	Key  []byte   `json:"k,omitempty"`
	Urls []string `json:"u"`
}

func EncodeToken(userID string, portalName string, aesKey []byte, urls ...string) (string, error) {
	if len(aesKey) == 0 {
		aesKey = nil
	}

	data, err := json.Marshal(_token{
		portalName, aesKey, urls,
	})
	if core.IsErr(err, "cannot marshal access information: %v") {
		return "", err
	}

	var buf bytes.Buffer
	w := gzip.NewWriter(&buf)
	_, err = io.Copy(w, bytes.NewBufferString(string(data)))
	w.Close()
	if core.IsErr(err, "cannot zip access information: %v") {
		return "", err
	}

	if len(userID) > 0 {
		data, err = security.EcEncrypt(userID, buf.Bytes())
		if core.IsErr(err, "cannot encrypt access token for %s", userID) {
			return "", err
		}
	}
	return strings.ReplaceAll(base64.StdEncoding.EncodeToString(data), "/", "_"), nil
}

func DecodeToken(identity security.Identity, access string) (portalName string, aesKey []byte, urls []string, err error) {
	if identity.Private == "" {
		return "", nil, nil,
			fmt.Errorf("cannot decode access token: no private key available for %s", identity.ID)
	}

	data, err := base64.StdEncoding.DecodeString(strings.ReplaceAll(access, "_", "/"))
	if core.IsErr(err, "cannot decode access token: %v") {
		return "", nil, nil, err
	}

	data2, err := security.EcDecrypt(identity, data)
	if err == nil {
		data = data2
	}

	r, err := gzip.NewReader(bytes.NewReader(data))
	if core.IsErr(err, "cannot unzip access token '%s': %v", access) {
		return "", nil, nil, err
	}

	var buf bytes.Buffer
	_, err = io.Copy(&buf, r)
	r.Close()
	if core.IsErr(err, "cannot unzip access token '%s': %v", access) {
		return "", nil, nil, err
	}

	var t _token
	err = json.Unmarshal(buf.Bytes(), &t)
	if core.IsErr(err, "cannot unmarshal access token '%s': %v", access) {
		return "", nil, nil, err
	}

	return t.Name, t.Key, t.Urls, err
}
