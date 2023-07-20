package safe

import (
	"testing"

	"github.com/stretchr/testify/assert"

	"github.com/stregato/master/woland/security"
	"github.com/stregato/master/woland/sql"
)

func TestOpen(t *testing.T) {
	sql.TestDB(t)

	// Prepare the necessary test inputs
	identity, err := security.NewIdentity("mock-identity")
	assert.NoError(t, err)
	access, err := CreateToken(identity, "test-save", nil, "mem://314") // Provide a mock access string
	assert.NoError(t, err)

	// Call the Open function
	s, err := Open(identity.ID(), access, OpenOptions{})
	assert.NoError(t, err)

	s.Close()
}
