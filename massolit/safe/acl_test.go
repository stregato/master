package safe

import (
	"testing"

	"github.com/stretchr/testify/assert"

	"github.com/stregato/master/massolit/core"
	"github.com/stregato/master/massolit/security"
	"github.com/stregato/master/massolit/storage"
)

func TestAclOnStore(t *testing.T) {
	store, err := storage.Open("mem://")
	assert.Nil(t, err)

	currentUser, err := security.NewIdentity("test")
	assert.Nil(t, err)

	acl := ACL{
		KeyId: core.NextID(0),
		KeyValues: map[string][]byte{
			"test": core.GenerateRandomBytes(KeySize),
		},
	}
	err = writeACL(currentUser, store, "test.acl", acl)
	assert.Nil(t, err)

	acl1, err := readACL(currentUser, store, "test.acl")
	assert.Nil(t, err)
	assert.Equal(t, acl, acl1)
}
