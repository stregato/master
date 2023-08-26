package safe

import (
	"fmt"
	"os"
	"path"
	"reflect"
	"time"

	"github.com/stregato/master/massolit/core"
	"github.com/stregato/master/massolit/security"
	"github.com/stregato/master/massolit/sql"
	"github.com/stregato/master/massolit/storage"
)

type ZoneSubscription struct {
	CreatorID     string
	ZoneName      string
	NameSignature []byte
}

type Event struct {
	SenderID string
	Type     string
	Content  []byte
}

func readEvents(currentUser security.Identity, store storage.Store, portalName string, zones map[string]*Zone) error {
	filter := storage.Filter{Suffix: ".ev", OnlyFiles: true}
	_, lastEventTime, _, ok := sql.GetConfig("lastEvent", portalName)
	if ok {
		filter.After = time.Unix(lastEventTime-1, 0)
	}

	ls, err := store.ReadDir(path.Join(UsersFolder, currentUser.ID), storage.Filter{Suffix: ".ev", OnlyFiles: true})
	if os.IsNotExist(err) {
		return nil
	}
	if core.IsErr(err, nil, "cannot read event folder in %s: %v", portalName) {
		return err
	}

	for _, f := range ls {
		var evt Event
		err = storage.ReadJSON(store, path.Join(UsersFolder, currentUser.ID, f.Name()), &evt, nil)
		if core.IsErr(err, nil, "cannot read event %s: %v", f.Name(), err) {
			continue
		}
		handleEvent(currentUser, store, portalName, zones, evt)
	}
	return nil
}

func handleEvent(currentUser security.Identity, store storage.Store, portalName string, zones map[string]*Zone, evt Event) error {
	data, err := security.EcDecrypt(currentUser, evt.Content)
	if core.IsErr(err, nil, "cannot decrypt event: %v", err) {
		return err
	}

	switch evt.Type {
	case "ZoneSubscription":
		var sub ZoneSubscription
		userID, err := security.Unmarshal(data, &sub, "s")
		if core.IsErr(err, nil, "cannot unmarshal ZoneSubscription: %v", err) {
			return err
		}
		if userID != evt.SenderID {
			return fmt.Errorf("ZoneSubscription sender ID %s does not match event sender ID %s", evt.SenderID, userID)
		}

		return handleZoneSubscription(currentUser, store, portalName, zones, sub)
	}
	return nil
}

func handleZoneSubscription(currentUser security.Identity, store storage.Store, portalName string, zones map[string]*Zone, sub ZoneSubscription) error {
	if !security.Verify(sub.CreatorID, []byte(sub.ZoneName), sub.NameSignature) {
		return ErrSignatureMismatch
	}

	zone := &Zone{
		CreatorId:     sub.CreatorID,
		NameSignature: sub.NameSignature,
		Keys:          map[uint64][]byte{},
	}

	err := syncZone(currentUser, store, portalName, sub.ZoneName, zone)
	if core.IsErr(err, nil, "cannot read zone %s: %v", sub.ZoneName, err) {
		return err
	}
	zones[sub.ZoneName] = zone

	return nil
}

func (p *Safe) SendEvent(userID string, content any) error {
	return sendEvent(p.CurrentUser, p.store, userID, content)
}

func sendEvent(currentUser security.Identity, store storage.Store, userID string, content any) error {
	data, err := security.Marshal(currentUser, content, "s")
	if core.IsErr(err, nil, "cannot marshal event: %v", err) {
		return err
	}
	data, err = security.EcEncrypt(userID, data)
	if core.IsErr(err, nil, "cannot encrypt event: %v", err) {
		return err
	}

	event := Event{
		SenderID: currentUser.ID,
		Type:     reflect.TypeOf(content).Name(),
		Content:  data,
	}

	err = storage.WriteJSON(store, path.Join(UsersFolder, userID, fmt.Sprintf("%d.ev", core.NextID(0))), event, nil)
	if core.IsErr(err, nil, "cannot write event: %v", err) {
		return err
	}

	return nil
}
