package sql

import (
	"github.com/stregato/master/woland/core"
)

func GetConfig(node string, key string) (s string, i int64, b []byte, ok bool) {
	var b64 string
	err := QueryRow("GET_CONFIG", Args{"node": node, "key": key}, &s, &i, &b64)
	switch err {
	case ErrNoRows:
		ok = false
	case nil:
		ok = true
		if b64 != "" {
			b = DecodeBase64(b64)
		}
	default:
		core.IsErr(err, nil, "cannot get config for %s/%s: %v", node, key)
		ok = false
	}
	core.Trace("SQL: GET_CONFIG: %s/%s - ok=%t, %s, %d, %d", node, key, ok, s, i, len(b))
	return s, i, b, ok
}

func SetConfig(node string, key string, s string, i int64, b []byte) error {
	b64 := EncodeBase64(b)
	_, err := Exec("SET_CONFIG", Args{"node": node, "key": key, "s": s, "i": i, "b": b64})
	if core.IsErr(err, nil, "cannot set config %s/%s with values %s, %d, %v: %v", node, key, s, i, b) {
		return err
	}
	core.Trace("SQL: SET_CONFIG: %s/%s - %s, %d, %d", node, key, s, i, len(b))
	return nil
}

func DelConfigs(node string) error {
	_, err := Exec("DEL_CONFIG", Args{"node": node})
	core.IsErr(err, nil, "cannot del configs %s", node)
	return err
}
