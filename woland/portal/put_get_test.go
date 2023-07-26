package portal

import (
	"bytes"
	"os"
	"testing"
	"time"

	"github.com/stretchr/testify/assert"

	"github.com/stregato/master/woland/core"
)

func TestPortalPut(t *testing.T) {
	StartTestDB(t)
	//	sql.OpenDB("/tmp/woland.db")
	portal := OpenTestPortal(t)

	zoneName := "toyroom"
	err := portal.CreateZone(zoneName, nil)
	assert.Nil(t, err)

	data := []byte("Hello, World!")
	r := core.NewBytesReader(data)

	portal.Put(zoneName, "file1", r, PutOptions{
		Tags:        []string{"tag1", "tag2"},
		ContentType: "text/plain",
	})

	headers, err := portal.List(zoneName, ListOptions{})
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
	_, err = portal.Get(zoneName, "file1", &b, GetOptions{})
	assert.NoError(t, err)
	assert.Equal(t, data, b.Bytes())

	headers, err = portal.List(zoneName, ListOptions{})
	core.TestErr(t, err, "cannot list files: %v")
	header = headers[0]
	if header.Cached == "" {
		t.Errorf("Expected cached to be set")
	}

	portal.Close()
}

func TestPortalPutAsync(t *testing.T) {
	StartTestDB(t)
	//	sql.OpenDB("/tmp/woland.db")
	portal := OpenTestPortal(t)

	zoneName := "toyroom"
	err := portal.CreateZone(zoneName, nil)
	assert.Nil(t, err)

	data := []byte("Hello, World!")
	r := core.NewBytesReader(data)

	portal.Put(zoneName, "file1", r, PutOptions{
		Tags:        []string{"tag1", "tag2"},
		ContentType: "text/plain",
	})
	portal.List(zoneName, ListOptions{})

	c := make(chan bool)
	b := bytes.Buffer{}
	_, err = portal.Get(zoneName, "file1", &b, GetOptions{
		Async: func(_ Header, err error) {
			assert.NoError(t, err)
			assert.Equal(t, data, b.Bytes())
			c <- true
		},
	})

	assert.NoError(t, err)
	if err == nil {
		<-c
	}

	portal.Close()
}

func TestPortalPutDestination(t *testing.T) {
	StartTestDB(t)
	//	sql.OpenDB("/tmp/woland.db")
	portal := OpenTestPortal(t)

	zoneName := "toyroom"
	err := portal.CreateZone(zoneName, nil)
	assert.Nil(t, err)

	data := []byte("Hello, World!")
	r := core.NewBytesReader(data)

	portal.Put(zoneName, "file1", r, PutOptions{
		Tags:        []string{"tag1", "tag2"},
		ContentType: "text/plain",
	})
	portal.List(zoneName, ListOptions{})

	tmpFile, _ := os.CreateTemp("/tmp", "woland")
	core.TestErr(t, err, "cannot create temp file: %v")
	defer os.Remove(tmpFile.Name())
	_, err = portal.Get(zoneName, "file1", tmpFile, GetOptions{
		Destination: tmpFile.Name(),
	})
	core.TestErr(t, err, "cannot get file: %v")
	tmpFile.Close()
	time.Sleep(time.Second)
	headers, err := portal.List(zoneName, ListOptions{})
	core.TestErr(t, err, "cannot list files: %v")
	header := headers[0]
	if _, ok := header.Downloads[tmpFile.Name()]; !ok {
		t.Errorf("Expected download to be recorded")
	}

	portal.Close()
}
