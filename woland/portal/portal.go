package portal

import (
	"os"
	"path/filepath"

	"github.com/stregato/master/woland/security"
	"github.com/stregato/master/woland/storage"
)

var CacheFolder string

func init() {
	dataDir, err := os.UserCacheDir()
	if err == nil {
		CacheFolder = filepath.Join(dataDir, "woland", "cache")
		os.MkdirAll(CacheFolder, 0755)
	}
}

type Portal struct {
	CurrentUser security.Identity `json:"currentUser"`
	Name        string            `json:"name"`
	store       storage.Store
	storeUrl    string
	zones       map[string]Zone
}
