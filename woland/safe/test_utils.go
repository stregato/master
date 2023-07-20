package safe

import (
	"testing"

	"github.com/stretchr/testify/assert"

	"github.com/stregato/master/woland/security"
	"github.com/stregato/master/woland/sql"
)

func StartTestDB(t *testing.T) {
	err := sql.OpenDB(sql.MemoryDB)
	assert.Nil(t, err)
}

func OpenTestSafe(t *testing.T) *Safe {
	identity, err := security.NewIdentity("test")
	assert.Nil(t, err)

	access, err := CreateToken(identity, "test", nil, "mem://")
	assert.Nil(t, err)

	safe, err := Open(identity.ID(), access, OpenOptions{})
	assert.Nil(t, err)

	return safe
}
