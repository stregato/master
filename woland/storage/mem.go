package storage

import (
	"bytes"
	"fmt"
	"io"
	"io/fs"
	"net/url"
	"os"
	"path"
	"strings"

	"github.com/code-to-go/woland/core"
)

type _memoryFile struct {
	simpleFileInfo simpleFileInfo
	content        []byte
}

type Memory struct {
	url  string
	data map[string]_memoryFile
}

func OpenMemory(connectionUrl string) (Store, error) {
	u, err := url.Parse(connectionUrl)
	if core.IsErr(err, "invalid URL: %v") {
		return nil, err
	}
	if u.Scheme != "mem" {
		return nil, os.ErrInvalid
	}

	url := fmt.Sprintf("mem://%d", core.Now().UnixMicro())
	return &Memory{url, map[string]_memoryFile{}}, nil
}

func (m *Memory) Read(name string, rang *Range, dest io.Writer, progress chan int64) error {
	f, ok := m.data[name]
	if !ok {
		return os.ErrNotExist
	}

	var err error
	var w int64
	if rang == nil {
		w, err = io.Copy(dest, core.NewBytesReader(f.content))
	} else {
		w, err = io.CopyN(dest, core.NewBytesReader(f.content[rang.From:]), rang.To-rang.From)
	}
	if core.IsErr(err, "cannot read from %s/%s:%v", m, name) {
		return err
	}
	if progress != nil {
		progress <- w
	}

	return nil
}

func (m *Memory) Write(name string, source io.ReadSeeker, progress chan int64) error {
	var buf bytes.Buffer

	_, err := io.Copy(&buf, source)
	if core.IsErr(err, "cannot copy file '%s'' in memory:%v", name) {
		return err
	}
	content := buf.Bytes()
	if progress != nil {
		progress <- int64(len(content))
	}

	m.data[name] = _memoryFile{
		simpleFileInfo: simpleFileInfo{
			name:    path.Base(name),
			size:    int64(len(content)),
			modTime: core.Now(),
			isDir:   false,
		},
		content: content,
	}

	return err
}

func (m *Memory) ReadDir(dir string, f Filter) ([]fs.FileInfo, error) {
	var infos []fs.FileInfo
	for n, mf := range m.data {
		if strings.HasPrefix(n, dir+"/") && matchFilter(mf.simpleFileInfo, f) {
			infos = append(infos, mf.simpleFileInfo)
		}
	}

	return infos, nil
}

func (m *Memory) Stat(name string) (os.FileInfo, error) {
	l, ok := m.data[name]
	if ok {
		return l.simpleFileInfo, nil
	} else {
		return nil, os.ErrNotExist
	}
}

func (m *Memory) Delete(name string) error {
	_, ok := m.data[name]
	if ok {
		delete(m.data, name)
		return nil
	} else {
		return os.ErrNotExist
	}
}

func (m *Memory) Close() error {
	return nil
}

func (m *Memory) String() string {
	return m.url
}
