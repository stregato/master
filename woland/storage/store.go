package storage

import (
	"io"
	"io/fs"
	"os"
	"strings"

	"github.com/code-to-go/woland/core"
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
	//Prefix filters on results starting with prefix
	Prefix string
	//Suffix filters on results ending with suffix
	Suffix string

	//After ignore all results before the provided one and the provided one
	After string

	//MaxResults is the maximal number of returned items
	MaxResults int64
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
