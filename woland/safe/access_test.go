package safe

import (
	"testing"

	"github.com/stretchr/testify/assert"

	"github.com/code-to-go/woland/security"
)

func TestNewAccess(t *testing.T) {

	identity, err := security.NewIdentity("test")
	assert.Nil(t, err)

	access, err := NewAccess(identity, "test", []string{"sftp://blabla"})
	assert.Nil(t, err)

	a, err := unwrapAccess(identity, access)
	assert.Nil(t, err)
	assert.Equal(t, "test", a.Name)

}
