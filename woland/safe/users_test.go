package safe

import (
	"bytes"
	"testing"

	"github.com/stregato/master/woland/core"
	"github.com/stregato/master/woland/sql"
)

func TestAddSecondUser(t *testing.T) {
	InitTest()

	StartTestDB(t, dbPath)

	s, err := Create(Identity1, testSafe, testStoreConfig, nil, CreateOptions{Wipe: true})
	core.Assert(t, err == nil, "Cannot create safe: %v", err)

	r := core.NewBytesReader(testData)
	_, err = Put(s, "bucket", "a1", r, PutOptions{}, nil)
	core.TestErr(t, err, "cannot put file: %v")

	r = core.NewBytesReader(testData)
	_, err = Put(s, "bucket", "a2", r, PutOptions{Private: Identity2.Id}, nil)
	core.TestErr(t, err, "cannot put file: %v")

	lastKeyId := s.Keystore.LastKeyId
	headersIds1, err := getHeadersIdsWithCount(s.PrimaryStore, s.Name, "bucket")
	core.TestErr(t, err, "cannot get headers ids: %v")

	err = SetUsers(s, map[string]Permission{Identity2.Id: Reader}, SetUsersOptions{})
	core.TestErr(t, err, "cannot set users: %v")
	core.Assert(t, s.Keystore.LastKeyId == lastKeyId, "Expected last key id to be %d, got %d", lastKeyId, s.Keystore.LastKeyId)

	users, err := GetUsers(s)
	core.TestErr(t, err, "cannot get users: %v")
	core.Assert(t, len(users) == 2, "Expected 2 users, got %d", len(users))
	core.Assert(t, users.Is(Identity1.Id, Creator), "Expected user %s to be creator, got %s", Identity1.Id, users[Identity1.Id])
	core.Assert(t, users.Is(Identity2.Id, Reader), "Expected user %s to be reader, got %s", Identity2.Id, users[Identity2.Id])

	Close(s)
	sql.CloseDB()

	StartTestDB(t, dbPath)

	s, err = Open(Identity2, testSafe, testUrl, Identity1.Id, OpenOptions{})
	core.TestErr(t, err, "cannot open safe: %v")
	core.Assert(t, s.Keystore.LastKeyId == lastKeyId, "Expected last key id to be %d, got %d", lastKeyId, s.Keystore.LastKeyId)

	users, err = GetUsers(s)
	core.TestErr(t, err, "cannot get users: %v")
	core.Assert(t, len(users) == 2, "Expected 2 users, got %d", len(users))
	core.Assert(t, users.Is(Identity1.Id, Creator), "Expected user %s to be creator, got %s", Identity1.Id, users[Identity1.Id])
	core.Assert(t, users.Is(Identity2.Id, Reader), "Expected user %s to be reader, got %s", Identity2.Id, users[Identity2.Id])

	files, err := ListFiles(s, "bucket", ListOptions{})
	core.TestErr(t, err, "cannot list files: %v")
	core.Assert(t, len(files) == 2, "Expected 2 files, got %d", len(files))

	b := bytes.NewBuffer(nil)
	h, err := Get(s, "bucket", "a1", b, GetOptions{})
	core.TestErr(t, err, "cannot get file: %v")
	core.Assert(t, bytes.Equal(testData, b.Bytes()), "Expected data to be '%s', got '%s'", testData, b.Bytes())
	core.Assert(t, h.Creator == Identity1.Id, "Expected creator to be %s, got %s", Identity1.Id, h.Creator)

	b = bytes.NewBuffer(nil)
	h, err = Get(s, "bucket", "a2", b, GetOptions{})
	core.TestErr(t, err, "cannot get file: %v")
	core.Assert(t, bytes.Equal(testData, b.Bytes()), "Expected data to be '%s', got '%s'", testData, b.Bytes())
	core.Assert(t, h.Creator == Identity1.Id, "Expected creator to be %s, got %s", Identity1.Id, h.Creator)
	core.Assert(t, h.PrivateId == Identity2.Id, "Expected private id to be %s, got %s", Identity2.Id, h.PrivateId)

	err = SetUsers(s, map[string]Permission{Identity1.Id: Reader}, SetUsersOptions{})
	core.Assert(t, err != nil, "Expected error, got nil")

	Close(s)
	sql.CloseDB()

	StartTestDB(t, dbPath)
	s, err = Open(Identity1, testSafe, testUrl, Identity1.Id, OpenOptions{})
	core.TestErr(t, err, "cannot open safe: %v")

	err = SetUsers(s, map[string]Permission{Identity2.Id: Suspended}, SetUsersOptions{SyncAlign: true})
	core.TestErr(t, err, "cannot set users: %v")
	core.Assert(t, s.Keystore.LastKeyId != lastKeyId, "Expected last key id to be different, got %d", s.Keystore.LastKeyId)

	ListFiles(s, "bucket", ListOptions{})

	headersIds2, err := getHeadersIdsWithCount(s.PrimaryStore, s.Name, "bucket")
	core.TestErr(t, err, "cannot get headers ids: %v")
	core.Assert(t, len(headersIds2) == 1, "Expected 1 headers id, got %d", len(headersIds2))
	for id := range headersIds1 {
		core.Assert(t, headersIds2[id] == 0, "Expected headers ids to be different, got %d", id)
	}
}
