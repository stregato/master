package safe

import (
	"fmt"
	"path"
	"time"

	"github.com/stregato/master/woland/core"
	"github.com/stregato/master/woland/security"
	"github.com/stregato/master/woland/storage"
)

type manifestFile struct {
	CreatorId      string        `json:"creatorId"`
	Description    string        `json:"description"`
	ChangeLogWatch time.Duration `json:"changeLogWatch"`
	ReplicaWatch   time.Duration `json:"replicaWatch"`
}

func readManifestFile(s storage.Store, creatorId string) (manifestFile, error) {
	var manifest manifestFile

	data, err := storage.ReadFile(s, path.Join(ConfigFolder, "manifest.json"))
	if core.IsErr(err, nil, "cannot read manifest file: %v", err) {
		return manifest, err
	}
	signedId, err := security.Unmarshal(data, &manifest, "signature")
	if core.IsErr(err, nil, "cannot read manifest file: %v", err) {
		return manifest, err
	}
	if signedId != creatorId {
		return manifest, fmt.Errorf("invalid manifest file: creatorId mismatch")
	}

	return manifest, nil
}

func writeManifestFile(s storage.Store, currentUser security.Identity, manifest manifestFile) error {
	data, err := security.Marshal(currentUser, manifest, "signature")
	if core.IsErr(err, nil, "cannot marshal manifest file: %v", err) {
		return err
	}

	err = storage.WriteFile(s, path.Join(ConfigFolder, "manifest.json"), data)
	if core.IsErr(err, nil, "cannot write manifest file: %v", err) {
		return err
	}

	return nil
}
