package portal

import (
	"testing"

	"github.com/stretchr/testify/assert"
)

func TestNewAccess(t *testing.T) {

	StartTestDB(t)

	access, err := EncodeToken(TestID, "test", nil, "sftp://blabla")
	assert.Nil(t, err)

	name, _, _, err := DecodeToken(TestIdentity, access)
	assert.Nil(t, err)
	assert.Equal(t, "test", name)

}
