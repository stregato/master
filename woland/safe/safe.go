package safe

import (
	"os"
	"path/filepath"

	"github.com/stregato/masterwoland/security"
	"github.com/stregato/masterwoland/storage"
)

var ConfigFolder string
var CacheFolder string

func init() {
	configDir, err := os.UserConfigDir()
	if err != nil {
		panic(err)
	}
	ConfigFolder = filepath.Join(configDir, "woland")
	os.MkdirAll(ConfigFolder, 0755)

	dataDir, err := os.UserCacheDir()
	if err != nil {
		panic(err)
	}
	CacheFolder = filepath.Join(dataDir, "woland", "cache")
	os.MkdirAll(CacheFolder, 0755)
}

type Safe struct {
	CurrentUser security.Identity `json:"currentUser"`
	Name        string            `json:"name"`
	IssuerId    string            `json:"issuerId"`
	store       storage.Store
	storeUrl    string
	zones       map[string]Zone
}
