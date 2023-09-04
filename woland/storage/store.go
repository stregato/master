package storage

import (
	"io"
	"io/fs"
	"os"
	"strings"
	"time"

	"gopkg.in/yaml.v2"

	"github.com/stregato/master/woland/core"
)

type Source struct {
	Name   string
	Data   []byte
	Reader io.Reader
	Size   int64
}

const SizeAll = -1

type ListOption uint32

const (
	// IncludeHiddenFiles includes hidden files in a list operation
	IncludeHiddenFiles ListOption = 1
)

type Range struct {
	From int64
	To   int64
}

type Filter struct {
	Prefix      string                 //Prefix filters on results starting with prefix
	Suffix      string                 //Suffix filters on results ending with suffix
	AfterName   string                 //After ignore all results before the provided one and the provided one
	After       time.Time              //After ignore all results before the provided one and the provided one
	MaxResults  int64                  //MaxResults limits the number of results returned
	OnlyFiles   bool                   //OnlyFiles returns only files
	OnlyFolders bool                   //OnlyFolders returns only folders
	Function    func(fs.FileInfo) bool //Function filters on a custom function
}

// Store is a low level interface to storage services such as S3 or SFTP
type Store interface {
	//ReadDir returns the entries of a folder content
	ReadDir(name string, filter Filter) ([]fs.FileInfo, error)

	// Read reads data from a file into a writer
	Read(name string, rang *Range, dest io.Writer, progress chan int64) error

	// Write writes data to a file name. An existing file is overwritten
	Write(name string, source io.ReadSeeker, progress chan int64) error

	// Stat provides statistics about a file
	Stat(name string) (os.FileInfo, error)

	// Delete deletes a file
	Delete(name string) error

	// Close releases resources
	Close() error

	// String returns a human-readable representation of the storer (e.g. sftp://user@host.cc/path)
	String() string
}

// Open creates a new exchanger giving a provided configuration
func Open(connectionUrl string) (Store, error) {
	switch {
	case strings.HasPrefix(connectionUrl, "sftp://"):
		return OpenSFTP(connectionUrl)
	case strings.HasPrefix(connectionUrl, "s3://"):
		return OpenS3(connectionUrl)
	case strings.HasPrefix(connectionUrl, "file:/"):
		return OpenLocal(connectionUrl)
	case strings.HasPrefix(connectionUrl, "dav://"):
		return OpenWebDAV(connectionUrl)
	case strings.HasPrefix(connectionUrl, "davs://"):
		return OpenWebDAV(connectionUrl)
	case strings.HasPrefix(connectionUrl, "mem://"):
		return OpenMemory(connectionUrl)
	}

	return nil, core.ErrNoDriver
}

func LoadTestURLs(filename string) (urls map[string]string) {
	data, err := os.ReadFile(filename)
	if core.IsErr(err, nil, "cannot read file %s: %v", filename) {
		panic(err)
	}

	err = yaml.Unmarshal(data, &urls)
	if core.IsErr(err, nil, "cannot parse file %s: %v", filename) {
		panic(err)
	}
	return urls
}
