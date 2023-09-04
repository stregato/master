package safe

import (
	"fmt"
	"path"
	"regexp"
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
	return dir
	// parts := strings.Split(dir, "/")
	// for idx, part := range parts {
	// 	hash := blake2b.Sum256([]byte(part))
	// 	parts[idx] = core.Encode(hash[:])
	// }
	// return path.Join(parts...)
}

func isAlphanumeric(s string) bool {
	match, _ := regexp.MatchString("^[a-zA-Z0-9]*$", s)
	return match
}
