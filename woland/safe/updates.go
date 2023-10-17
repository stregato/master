package safe

import (
	"time"

	"github.com/stregato/master/woland/core"
	"github.com/stregato/master/woland/sql"
)

func CheckForUpdates(s *Safe, dir string, after time.Time, depth int) ([]string, error) {
	dirs := []string{dir}

	synchorize(s.CurrentUser, s.stores[0], s.Name, hashPath(dir), depth, s.keys)

	if depth != 0 {
		nested, err := ListDirs(s, dir, ListDirsOptions{
			Depth: depth,
		})
		if core.IsErr(err, nil, "cannot list dirs in %s: %v", dir) {
			return nil, err
		}
		dirs = append(dirs, nested...)
	}
	ch := make(chan string)
	for _, d := range dirs {
		go func(d string) {
			hashedDir := hashPath(d)
			_, i, _, ok := sql.GetConfig("SAFE_DIR_MODTIME", hashedDir)
			if !ok && after.IsZero() {
				core.Info("dir %s has been added", d)
				ch <- d
			} else {
				touch, err := GetTouch(s.stores[0], DataFolder, hashedDir, ".touch")
				core.IsErr(err, nil, "cannot check touch file: %v", err)

				if touch.After(after) && time.Unix(i, 0) != touch {
					core.Info("dir %s has been modified", d)
					ch <- d
				} else {
					ch <- ""
				}
			}
		}(d)
	}
	var updates []string
	for i := 0; i < len(dirs); i++ {
		d := <-ch
		if d != "" {
			updates = append(updates, d)
		}
	}
	return updates, nil
}
