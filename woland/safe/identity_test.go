package safe

import (
	"path"
	"testing"

	"github.com/stretchr/testify/assert"

	"github.com/stregato/master/woland/security"
	"github.com/stregato/master/woland/sql"
	"github.com/stregato/master/woland/storage"
)

func TestSyncIdentities(t *testing.T) {
	err := sql.OpenDB(sql.MemoryDBPath)
	assert.Nil(t, err)

	s, err := storage.Open("mem://")
	assert.Nil(t, err)

	s1, err := security.NewIdentity("s1")
	assert.Nil(t, err)
	s2, err := security.NewIdentity("s2")
	assert.Nil(t, err)

	ls, err := s.ReadDir(path.Join("test", IdentitiesFolder), storage.Filter{})
	assert.Nil(t, err)
	assert.Empty(t, ls)

	identities, err := security.GetIdentities()
	assert.Nil(t, err)
	assert.Empty(t, identities)

	err = writeIdentity(s, s1)
	assert.Nil(t, err)
	err = writeIdentity(s, s2)
	assert.Nil(t, err)

	security.SetIdentity(s1)
	security.SetIdentity(s2)
	identities, err = security.GetIdentities()
	assert.Nil(t, err)
	assert.Equal(t, 2, len(identities))

	err = security.DelIdentity(s1.Id)
	assert.Nil(t, err)

	identities, err = security.GetIdentities()
	assert.Nil(t, err)
	assert.Equal(t, 1, len(identities))

	_, err = readIdentities(s)
	assert.Nil(t, err)
	identities, err = security.GetIdentities()
	assert.Nil(t, err)
	assert.Equal(t, 2, len(identities))

	sql.CloseDB()
}
