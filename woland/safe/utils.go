package safe

import (
	"encoding/base64"
	"fmt"
	"path"
	"regexp"
	"strings"

	"golang.org/x/crypto/blake2b"
)

var ErrInvalidTag = fmt.Errorf("invalid tag. Only alphanumeric characters are allowed")

func getTagsArg(tags []string) (string, error) {
	arg := ""
	for _, tag := range tags {
		if !isAlphanumeric(tag) {
			return "", ErrInvalidTag
		}
		arg += tag + " %"
	}

	return arg, nil
}

func getDir(name string) string {
	dir := path.Dir(name)
	if dir == "." {
		return ""
	}
	return dir
}

func hashPath(dir string) string {
	h := blake2b.Sum256([]byte(dir))
	return strings.ReplaceAll(base64.StdEncoding.EncodeToString(h[:]), "/", "_")
}

func isAlphanumeric(s string) bool {
	match, _ := regexp.MatchString("^[a-zA-Z0-9]*$", s)
	return match
}
