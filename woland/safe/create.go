package safe

import (
	"fmt"
	"os"
	"strings"
	"time"

	"github.com/godruoyi/go-snowflake"

	"github.com/stregato/master/woland/core"
	"github.com/stregato/master/woland/security"
)

type CreateOptions struct {
	Wipe           bool          `json:"wipe"`           // Wipe is true if the safe should be wiped before creating it
	Description    string        `json:"description"`    // Description of the safe
	ChangeLogWatch time.Duration `json:"changeLogWatch"` // ChangeLogWatch is the period for watching changes in the change log
	ReplicaWatch   time.Duration `json:"replicaWatch"`   // ReplicaWatch is the period for synchronizing replicas
}

const (
	DefaultChangeLogWatch = time.Minute
	DefaultReplicaWatch   = 10 * time.Minute
)

func Create(currentUser security.Identity, access string, options CreateOptions) (*Safe, error) {
	name, creatorId, aesKey, urls, err := DecodeAccess(currentUser, access)
	if core.IsErr(err, nil, "invalid access token 'account'") {
		return nil, err
	}

	if creatorId != currentUser.Id {
		return nil, fmt.Errorf("invalid access token 'account'")
	}

	stores, failedUrls, err := connect(urls, name, aesKey)
	if core.IsErr(err, nil, "cannot connect to %s: %v", name) {
		return nil, err
	}
	if len(failedUrls) > 0 {
		return nil, fmt.Errorf("cannot connect to all stores, which is mandatory for create; "+
			"missing stores: %v", strings.Join(failedUrls, ","))
	}

	for _, store := range stores {
		_, err = store.Stat("")
		if !os.IsNotExist(err) {
			if options.Wipe {
				store.Delete("")
			} else {
				return nil, fmt.Errorf("safe already exist: name %s", name)
			}
		}
	}

	keyId := snowflake.ID()
	key := core.GenerateRandomBytes(KeySize)
	keys := map[uint64][]byte{keyId: key}
	users := Users{creatorId: PermissionRead + PermissionWrite + PermissionAdmin + PermissionSuperAdmin}

	if options.ChangeLogWatch == 0 {
		options.ChangeLogWatch = DefaultChangeLogWatch
	}
	if options.ReplicaWatch == 0 {
		options.ReplicaWatch = DefaultReplicaWatch
	}

	err = writeManifestFile(stores[0], currentUser, manifestFile{
		CreatorId:      creatorId,
		Description:    options.Description,
		ChangeLogWatch: options.ChangeLogWatch,
		ReplicaWatch:   options.ReplicaWatch,
	})
	if core.IsErr(err, nil, "cannot write manifest file in %s: %v", name) {
		return nil, err
	}

	err = writePermissionChange(stores[0], name, currentUser, users)
	if core.IsErr(err, nil, "cannot write permission change in %s: %v", name) {
		return nil, err
	}

	err = writeKeyStore(stores[0], name, currentUser, keyId, key, users)
	if core.IsErr(err, nil, "cannot write keystore in %s: %v", name) {
		return nil, err
	}

	return &Safe{
		CurrentUser: currentUser,
		CreatorId:   creatorId,
		Name:        name,
		Description: options.Description,
		users:       users,
		keyId:       keyId,
		keys:        keys,
		stores:      stores,
	}, nil
}
