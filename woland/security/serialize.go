package security

import (
	"bytes"
	"encoding/base64"
	"encoding/json"
	"fmt"
	"regexp"
	"strings"

	"github.com/stregato/master/woland/core"
)

const SignatureField = "dgst_ed25519_blake2b"

func Marshal(identity Identity, v any, signatureField string) ([]byte, error) {
	data, err := json.MarshalIndent(v, "", " ")
	if core.IsErr(err, nil, "cannot marshal to json: %v") {
		return data, err
	}

	s := strings.Trim(string(data), " ")
	if len(s) == 0 {
		return nil, &json.MarshalerError{}
	}

	hs := QuickHash([]byte(s))
	signature, err := Sign(identity, hs)
	if core.IsErr(err, nil, "cannot sign json payload: %v") {
		return nil, err
	}

	last := rune(s[len(s)-1])
	switch last {
	case '}':
		s = fmt.Sprintf(`%s,"%s":"%s:%s"}`, s[0:len(s)-1], signatureField, identity.Id,
			base64.StdEncoding.EncodeToString(signature))
	case ']':
		s = fmt.Sprintf(`%s,"%s:%s"]`, s[0:len(s)-1], identity.Id,
			base64.StdEncoding.EncodeToString(signature))
	default:
		return nil, &json.MarshalerError{}
	}
	return []byte(s), nil
}

var listRegex = regexp.MustCompile(`(,\s*"([\w+@_=\/]+):([\w+@_=\/]+)")]$`)

func Unmarshal(data []byte, v any, signatureField string) (id string, err error) {
	var sig []byte
	var loc []int
	data = bytes.TrimRight(data, " ")
	if len(data) == 0 {
		return "", &json.SyntaxError{Offset: 0}
	}
	last := data[len(data)-1]
	switch last {
	case '}':
		dictRegex := regexp.MustCompile(fmt.Sprintf(`(,\s*"%s"\s*:\s*"([\w+@_=\/]+):([\w+@_=\/]+)").*`, signatureField))
		loc = dictRegex.FindSubmatchIndex(data)
	case ']':
		loc = listRegex.FindSubmatchIndex(data)
	}
	if len(loc) != 8 {
		return "", fmt.Errorf("no signature field dgst_ed25519_blake2b in data")
	}

	id = string(data[loc[4]:loc[5]])
	signature64 := string(data[loc[6]:loc[7]])
	sig, err = base64.StdEncoding.DecodeString(signature64)
	if core.IsErr(err, nil, "cannot decode signature: %v") {
		return "", err
	}

	data2 := data[0:loc[2]]
	data2 = append(data2, data[loc[3]:]...)

	err = json.Unmarshal(data2, v)
	if core.IsErr(err, nil, "invalid json: %v") {
		return "", err
	}

	hs := QuickHash(data2)
	if !Verify(id, hs, sig) {
		core.IsErr(ErrInvalidSignature, nil, "invalid signature %s: %v", id)
		return "", ErrInvalidSignature
	}

	return id, err
}
