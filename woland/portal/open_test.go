package portal

import (
	"testing"

	"github.com/stregato/master/woland/core"
)

func TestOpen(t *testing.T) {
	StartTestDB(t)

	// Prepare the necessary test inputs
	//	access, err := EncodeToken(TestID, "test-save", nil, "mem://314") // Provide a mock access string
	access, err := EncodeToken(TestID, "test-save", nil, "sftp://sftp_user:11H%5Em63W5vAL@localhost/sftp_user") // Provide a mock access string
	core.TestErr(t, err, "cannot encode access token: %v")

	// Call the Open function
	p, err := Open(TestIdentity, access, OpenOptions{})
	core.TestErr(t, err, "cannot open portal: %v")

	p.Close()
}
