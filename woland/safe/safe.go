package safe

import (
	"os"
	"path/filepath"
	"time"

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

const (
	ConfigFolder = "config"
	DataFolder   = "data"
)

const KeySize = 32

type Keys map[uint64][]byte

type Safe struct {
	CurrentUser security.Identity   `json:"currentUser"` // Current user
	Access      string              `json:"access"`      // Access token
	CreatorId   string              `json:"creatorId"`   // Creator of the safe
	Name        string              `json:"name"`        // Name of the safe including the path
	Permission  Permission          `json:"permission"`  // Permission of the current user
	Description string              `json:"description"` // Description of the safe
	Storage     storage.Description `json:"storage"`     // Information about the store
	Quota       int64               `json:"quota"`       // Quota of the safe in bytes
	QuotaGroup  string              `json:"quotaGroup"`  // QuotaGroup is the common prefix for the safes that share the quota
	Size        int64               `json:"size"`        // Size of the safe in bytes

	users                Users // Users and their permissions
	keyId                uint64
	keys                 Keys
	identities           []security.Identity
	stores               []storage.Store
	newestChangeFile     string
	lastIdentitiesUpdate time.Time
}

// Admins defines the users who are administrators of a box and for each those that have level2, i.e. can add or remove other administrators
type Admins map[string]Level2

type Level2 bool

// Keystore is the file that contains the primary key of box encrypted for each user
type Keystore struct {
	KeyId uint64            `json:"keyId"`
	Keys  map[string][]byte `json:"keys"`
}
