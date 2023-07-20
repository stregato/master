package safe

import (
	"fmt"
	"testing"

	"github.com/stretchr/testify/assert"

	"github.com/stregato/masterwoland/security"
	"github.com/stregato/masterwoland/storage"
)

func TestCreateZone(t *testing.T) {
	StartTestDB(t)
	safe := OpenTestSafe(t)

	zoneName := "toyroom"
	err := safe.CreateZone(zoneName, nil)
	assert.Nil(t, err)

	zones, err := safe.Zones()
	assert.Nil(t, err)

	if len(zones) != 1 || zones[0] != "toyroom" {
		t.Errorf("expected 1 zone, got %d", len(zones))
	}

	userX, _ := security.NewIdentity("userX")
	safe.SetUsers(zoneName, Users{userX.ID(): PermissionUser})

	for i := 0; i < 4; i++ {
		user, _ := security.NewIdentity(fmt.Sprintf("user%d", i))
		safe.SetUsers(zoneName, Users{user.ID(): PermissionUser})
	}

	users, err := safe.GetUsers(zoneName)
	assert.Nil(t, err)

	if len(users) != 12 {
		t.Errorf("expected 12 users, got %d", len(users))
	}

	ls := storage.Dump(safe.store, "", true)
	print(ls)

	safe.Close()
	safe = OpenTestSafe(t)

	ls = storage.Dump(safe.store, "", true)
	print(ls)
}
