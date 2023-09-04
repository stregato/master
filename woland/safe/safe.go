package safe

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

const (
	ConfigFolder = "config"
	DataFolder   = "data"
)

const KeySize = 32

type Keys map[uint64][]byte

type Safe struct {
	CurrentUser security.Identity `json:"currentUser"`
	CreatorId   string            `json:"creatorId"`
	Name        string            `json:"name"`        // Name of the box including the path
	Description string            `json:"description"` // Description of the box

	users            Users // Users and their permissions
	keyId            uint64
	keys             Keys
	identities       []security.Identity
	stores           []storage.Store
	newestChangeFile string
}

// Admins defines the users who are administrators of a box and for each those that have level2, i.e. can add or remove other administrators
type Admins map[string]Level2

type Level2 bool

// Keystore is the file that contains the primary key of box encrypted for each user
type Keystore struct {
	KeyId uint64            `json:"keyId"`
	Keys  map[string][]byte `json:"keys"`
}
