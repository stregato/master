package safe

import (
	"testing"

	"github.com/stretchr/testify/assert"

	"github.com/stregato/masterwoland/security"
)

func TestNewAccess(t *testing.T) {

	identity, err := security.NewIdentity("test")
	assert.Nil(t, err)

	access, err := CreateToken(identity, "test", nil, "sftp://blabla")
	assert.Nil(t, err)

	name, _, _, _, err := unwrapToken(identity, access)
	assert.Nil(t, err)
	assert.Equal(t, "test", name)

}
