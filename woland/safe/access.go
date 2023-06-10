package safe

import (
	"bytes"
	"compress/gzip"
	"encoding/base64"
	"io"
	"strings"

	"github.com/code-to-go/safepool/core"

	"github.com/code-to-go/woland/security"
)

type _access struct {
	Name   string   `json:"n"`
	Stores []string `json:"s"`
	Issuer string   `json:"-"`
}

func NewAccess(identity security.Identity, name string, stores []string) (string, error) {
	data, err := security.Marshal(identity, _access{
		name, stores, "",
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

	data, err = security.EcEncrypt(identity.Id(), buf.Bytes())
	if core.IsErr(err, "cannot encrypt access token for %s", identity) {
		return "", err
	}

	return strings.ReplaceAll(base64.StdEncoding.EncodeToString(data), "/", "_"), nil
}

func unwrapAccess(identity security.Identity, access string) (_access, error) {
	data, err := base64.StdEncoding.DecodeString(strings.ReplaceAll(access, "_", "/"))
	if core.IsErr(err, "cannot decode access token: %v") {
		return _access{}, err
	}

	data, err = security.EcDecrypt(identity, data)
	if core.IsErr(err, "cannot decrypt access token for %s: %v", identity) {
		return _access{}, err
	}

	r, err := gzip.NewReader(bytes.NewReader(data))
	if core.IsErr(err, "cannot unzip access token '%s': %v", access) {
		return _access{}, err
	}

	var buf bytes.Buffer
	_, err = io.Copy(&buf, r)
	r.Close()
	if core.IsErr(err, "cannot unzip access token '%s': %v", access) {
		return _access{}, err
	}

	var a _access
	id, err := security.Unmarshal(buf.Bytes(), a, "g")
	if core.IsErr(err, "cannot unmarshal access token '%s': %v", access) {
		return _access{}, err
	}

	a.Issuer = id
	return a, err
}
