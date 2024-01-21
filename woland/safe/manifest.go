package safe

import (
	"fmt"
	"path"

	"github.com/stregato/master/woland/core"
	"github.com/stregato/master/woland/security"
	"github.com/stregato/master/woland/storage"
)

type Manifest struct {
	CreatorId   string `json:"creatorId"`   // CreatorId is the id of the creator of the safe
	Description string `json:"description"` // Description of the safe
}

func syncManifest(s *Safe) error {
	synced, _ := GetCached(s.Name, s.PrimaryStore, "config/.manifest.touch", nil, "")
	if !synced {
		manifest, err := readManifest(s.Name, s.PrimaryStore, s.CreatorId)
		if core.IsErr(err, nil, "cannot read manifest from store %s: %v", err) {
			return err
		}
		s.Description = manifest.Description
		err = setSafeConfigToDB(s.Name, safeConfig{
			Description: manifest.Description,
			Keystore:    s.Keystore,
			Users:       s.Users,
		})
		if core.IsErr(err, nil, "cannot set safe config to DB: %v") {
			return err
		}
	}
	return nil
}

func readManifest(safeName string, s storage.Store, creatorId string) (Manifest, error) {
	var manifest Manifest

	synced, err := GetCached(safeName, s, "config/.manifest.touch", &manifest, "")
	if core.IsErr(err, nil, "cannot check manifest file: %v") {
		return manifest, err
	}
	if synced {
		core.Info("manifest file is up to date")
		return manifest, nil
	}

	data, err := storage.ReadFile(s, path.Join(safeName, ConfigFolder, "manifest.json"))
	if core.IsErr(err, nil, "cannot read manifest file: %v") {
		return manifest, err
	}
	signedId, err := security.Unmarshal(data, &manifest, "signature")
	if core.IsErr(err, nil, "cannot read manifest file: %v") {
		return manifest, err
	}
	if signedId != creatorId {
		return manifest, fmt.Errorf("invalid manifest file: creatorId mismatch")
	}

	if creatorId != "" && creatorId != manifest.CreatorId {
		return manifest, fmt.Errorf("mismatch creatorId")
	}

	err = SetCached(safeName, s, "config/.manifest.touch", &manifest, "")
	if core.IsErr(err, nil, "cannot set manifest cache: %v") {
		return manifest, err
	}

	return manifest, nil
}

func writeManifest(safeName string, s storage.Store, currentUser security.Identity, manifest Manifest) error {
	data, err := security.Marshal(currentUser, manifest, "signature")
	if core.IsErr(err, nil, "cannot marshal manifest file: %v", err) {
		return err
	}

	err = storage.WriteFile(s, path.Join(safeName, ConfigFolder, "manifest.json"), data)
	if core.IsErr(err, nil, "cannot write manifest file: %v", err) {
		return err
	}

	err = SetCached(safeName, s, "config/.manifest.touch", &manifest, currentUser.Id)
	if core.IsErr(err, nil, "cannot set manifest cache: %v") {
		return err
	}

	return nil
}
