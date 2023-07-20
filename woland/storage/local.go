package storage

import (
	"io"
	"io/fs"
	"net/url"
	"os"
	"path"
	"path/filepath"
	"time"

	"github.com/stregato/master/woland/core"
)

type LocalConfig struct {
	Base string `json:"base" yaml:"base"`
}

type Local struct {
	base  string
	url   string
	touch map[string]time.Time
}

func OpenLocal(connectionUrl string) (Store, error) {
	u, err := url.Parse(connectionUrl)
	if core.IsErr(err, "invalid URL: %v") {
		return nil, err
	}

	base := u.Path
	if base == "" {
		base = "/"
	}
	return &Local{base, connectionUrl, map[string]time.Time{}}, nil
}

func (l *Local) Read(name string, rang *Range, dest io.Writer, progress chan int64) error {
	f, err := os.Open(path.Join(l.base, name))
	if core.IsErr(err, "cannot open file on %v:%v", l) {
		return err
	}

	if rang == nil {
		_, err = io.Copy(dest, f)
	} else {
		left := rang.To - rang.From
		f.Seek(rang.From, 0)
		var b [4096]byte

		for left > 0 && err == nil {
			var sz int64
			if rang.From-rang.To > 4096 {
				sz = 4096
			} else {
				sz = rang.From - rang.To
			}
			_, err = f.Read(b[0:sz])
			dest.Write(b[0:sz])
			left -= sz
		}
	}
	if core.IsErr(err, "cannot read from %s/%s:%v", l, name) {
		return err
	}

	return nil
}

func createDir(n string) error {
	return os.MkdirAll(filepath.Dir(n), 0755)
}

func (l *Local) Write(name string, source io.ReadSeeker, progress chan int64) error {
	n := filepath.Join(l.base, name)
	err := createDir(n)
	if core.IsErr(err, "cannot create parent of %s: %v", n) {
		return err
	}

	f, err := os.Create(n)
	if core.IsErr(err, "cannot create file on %v:%v", l) {
		return err
	}
	defer f.Close()

	_, err = io.Copy(f, source)
	core.IsErr(err, "cannot copy file on %v:%v", l)
	return err
}

func (l *Local) ReadDir(dir string, filter Filter) ([]fs.FileInfo, error) {
	result, err := os.ReadDir(dir)
	if err != nil {
		return nil, err
	}

	var infos []fs.FileInfo
	var cnt int64
	for _, item := range result {
		info, err := item.Info()
		if err == nil && matchFilter(info, filter) {
			infos = append(infos, info)
			cnt++
		}
		if filter.MaxResults > 0 && cnt == filter.MaxResults {
			break
		}
	}

	return infos, nil
}

func (l *Local) Stat(name string) (os.FileInfo, error) {
	return os.Stat(path.Join(l.base, name))
}

func (l *Local) Rename(old, new string) error {
	return os.Rename(path.Join(l.base, old), path.Join(l.base, new))
}

func (l *Local) Delete(name string) error {
	return os.Remove(path.Join(l.base, name))
}

func (l *Local) Close() error {
	return nil
}

func (l *Local) String() string {
	return l.url
}