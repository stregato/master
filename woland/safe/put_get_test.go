package safe

import (
	"bytes"
	"os"
	"testing"
	"time"

	"github.com/stretchr/testify/assert"

	"github.com/stregato/master/woland/core"
)

func TestSafePut(t *testing.T) {
	StartTestDB(t)
	//	sql.OpenDB("/tmp/woland.db")
	safe := OpenTestSafe(t)

	zoneName := "toyroom"
	err := safe.CreateZone(zoneName, nil)
	assert.Nil(t, err)

	data := []byte("Hello, World!")
	r := core.NewBytesReader(data)

	safe.Put(zoneName, "file1", r, PutOptions{
		Tags:        []string{"tag1", "tag2"},
		ContentType: "text/plain",
	})

	headers, err := safe.List(zoneName, ListOptions{})
	core.TestErr(t, err, "cannot list files: %v")
	if len(headers) != 1 {
		t.Errorf("Expected 1 file, got %d", len(headers))
	}
	header := headers[0]
	if header.Name != "file1" {
		t.Errorf("Expected file name to be 'file1', got '%s'", header.Name)
	}
	if header.Size != int64(len(data)) {
		t.Errorf("Expected file size to be %d, got %d", len(data), header.Size)
	}

	b := bytes.Buffer{}
	err = safe.Get(zoneName, "file1", &b, GetOptions{})
	assert.NoError(t, err)
	assert.Equal(t, data, b.Bytes())

	headers, err = safe.List(zoneName, ListOptions{})
	core.TestErr(t, err, "cannot list files: %v")
	header = headers[0]
	if header.Cached == "" {
		t.Errorf("Expected cached to be set")
	}

	safe.Close()
}

func TestSafePutAsync(t *testing.T) {
	StartTestDB(t)
	//	sql.OpenDB("/tmp/woland.db")
	safe := OpenTestSafe(t)

	zoneName := "toyroom"
	err := safe.CreateZone(zoneName, nil)
	assert.Nil(t, err)

	data := []byte("Hello, World!")
	r := core.NewBytesReader(data)

	safe.Put(zoneName, "file1", r, PutOptions{
		Tags:        []string{"tag1", "tag2"},
		ContentType: "text/plain",
	})
	safe.List(zoneName, ListOptions{})

	c := make(chan bool)
	b := bytes.Buffer{}
	err = safe.Get(zoneName, "file1", &b, GetOptions{
		Async: func(_ uint64, err error) {
			assert.NoError(t, err)
			assert.Equal(t, data, b.Bytes())
			c <- true
		},
	})

	assert.NoError(t, err)
	if err == nil {
		<-c
	}

	safe.Close()
}

func TestSafePutDestination(t *testing.T) {
	StartTestDB(t)
	//	sql.OpenDB("/tmp/woland.db")
	safe := OpenTestSafe(t)

	zoneName := "toyroom"
	err := safe.CreateZone(zoneName, nil)
	assert.Nil(t, err)

	data := []byte("Hello, World!")
	r := core.NewBytesReader(data)

	safe.Put(zoneName, "file1", r, PutOptions{
		Tags:        []string{"tag1", "tag2"},
		ContentType: "text/plain",
	})
	safe.List(zoneName, ListOptions{})

	tmpFile, _ := os.CreateTemp("/tmp", "woland")
	core.TestErr(t, err, "cannot create temp file: %v")
	defer os.Remove(tmpFile.Name())
	err = safe.Get(zoneName, "file1", tmpFile, GetOptions{
		Destination: tmpFile.Name(),
	})
	core.TestErr(t, err, "cannot get file: %v")
	tmpFile.Close()
	time.Sleep(time.Second)
	headers, err := safe.List(zoneName, ListOptions{})
	core.TestErr(t, err, "cannot list files: %v")
	header := headers[0]
	if _, ok := header.Downloads[tmpFile.Name()]; !ok {
		t.Errorf("Expected download to be recorded")
	}

	safe.Close()
}
