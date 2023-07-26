package portal

import (
	"fmt"
	"testing"

	"github.com/stretchr/testify/assert"

	"github.com/stregato/master/woland/security"
	"github.com/stregato/master/woland/storage"
)

func TestCreateZone(t *testing.T) {
	StartTestDB(t)
	portal := OpenTestPortal(t)

	zoneName := "toyroom"
	err := portal.CreateZone(zoneName, nil)
	assert.Nil(t, err)

	zones, err := portal.Zones()
	assert.Nil(t, err)

	if len(zones) != 1 || zones[0] != "toyroom" {
		t.Errorf("expected 1 zone, got %d", len(zones))
	}

	userX, _ := security.NewIdentity("userX")
	portal.SetUsers(zoneName, Users{userX.ID: PermissionUser})

	for i := 0; i < 4; i++ {
		user, _ := security.NewIdentity(fmt.Sprintf("user%d", i))
		portal.SetUsers(zoneName, Users{user.ID: PermissionUser})
	}

	users, err := portal.GetUsers(zoneName)
	assert.Nil(t, err)

	if len(users) != 12 {
		t.Errorf("expected 12 users, got %d", len(users))
	}

	ls := storage.Dump(portal.store, "", true)
	print(ls)

	portal.Close()
	portal = OpenTestPortal(t)

	ls = storage.Dump(portal.store, "", true)
	print(ls)
}
