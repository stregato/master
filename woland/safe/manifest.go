package safe

import (
	"fmt"

	"github.com/stregato/master/massolit/core"
	"github.com/stregato/master/massolit/security"
	"github.com/stregato/master/massolit/storage"
)

func readManifestFile(s storage.Store, creatorId string) (manifestFile, error) {
	var manifest manifestFile

	data, err := storage.ReadFile(s, "manifest.json")
	signedId, err := security.Unmarshal(data, &manifest, "signature")
	if core.IsErr(err, nil, "cannot read manifest file: %v", err) {
		return manifest, err
	}
	if signedId != creatorId {
		return manifest, fmt.Errorf("invalid manifest file: creatorId mismatch")
	}

	return manifest, nil
}
