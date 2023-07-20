package safe

import (
	"bytes"
	"compress/gzip"
	"encoding/base64"
	"io"
	"strings"

	"github.com/stregato/master/woland/core"
	"github.com/stregato/master/woland/security"
)

type _token struct {
	Name string   `json:"n"`
	Key  []byte   `json:"k"`
	Urls []string `json:"u"`
}

func CreateToken(identity security.Identity, name string, key []byte, urls ...string) (string, error) {
	data, err := security.Marshal(identity, _token{
		name, key, urls,
	}, "g")
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

	data, err = security.EcEncrypt(identity.ID(), buf.Bytes())
	if core.IsErr(err, "cannot encrypt access token for %s", identity) {
		return "", err
	}

	return strings.ReplaceAll(base64.StdEncoding.EncodeToString(data), "/", "_"), nil
}

func unwrapToken(identity security.Identity, access string) (name string, key []byte, urls []string, issuerId string, err error) {
	data, err := base64.StdEncoding.DecodeString(strings.ReplaceAll(access, "_", "/"))
	if core.IsErr(err, "cannot decode access token: %v") {
		return "", nil, nil, "", err
	}

	data, err = security.EcDecrypt(identity, data)
	if core.IsErr(err, "cannot decrypt access token for %s: %v", identity) {
		return "", nil, nil, "", err
	}

	r, err := gzip.NewReader(bytes.NewReader(data))
	if core.IsErr(err, "cannot unzip access token '%s': %v", access) {
		return "", nil, nil, "", err
	}

	var buf bytes.Buffer
	_, err = io.Copy(&buf, r)
	r.Close()
	if core.IsErr(err, "cannot unzip access token '%s': %v", access) {
		return "", nil, nil, "", err
	}

	var t _token
	id, err := security.Unmarshal(buf.Bytes(), &t, "g")
	if core.IsErr(err, "cannot unmarshal access token '%s': %v", access) {
		return "", nil, nil, "", err
	}

	return t.Name, t.Key, t.Urls, id, err
}
