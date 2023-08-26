package safe

import (
	"os"
	"path/filepath"

	"github.com/stregato/master/massolit/security"
	"github.com/stregato/master/massolit/storage"
)

var CacheFolder string

func init() {
	dataDir, err := os.UserCacheDir()
	if err == nil {
		CacheFolder = filepath.Join(dataDir, "massolit", "cache")
		os.MkdirAll(CacheFolder, 0755)
	}
}

type Safe struct {
	CurrentUser security.Identity `json:"currentUser"`
	CreatorId   string            `json:"creatorId"`
	Name        string            `json:"name"`    // Name of the box including the path
	Description string            `json:"desc"`    // Description of the box
	Relaxed     bool              `json:"relaxed"` // If true, all peers are allowed to add or remove other users
	Admins      Admins            `json:"admins"`  // List of administrators and their level of access

	primaryKey []byte
	identities []security.Identity
	store      storage.Store
	storeUrl   string
}

// Admins defines the users who are administrators of a box and for each those that have level2, i.e. can add or remove other administrators
type Admins map[string]Level2

type Level2 bool

// Grant is a permission grant to define the level of access to a box for administators
type Grant struct {
	UserId    string `json:"userId"`    // User ID of the user to grant the permission
	Level2    Level2 `json:"level2"`    // If true, the user is a level2 administrator and can add or remove other administrators
	By        string `json:"by"`        // User ID of the entity who signed the grant
	Signature []byte `json:"signature"` // Cryptographic signature of the hash of the grant
}

// AdminFile is a list of grants
type AdminFile struct {
	Grants []Grant `json:"grants"`
}

// Keystore is the file that contains the primary key of box encrypted for each user
type Keystore struct {
	KeyId uint64            `json:"keyId"`
	Keys  map[string][]byte `json:"keys"`
}

type manifestFile struct {
	CreatorId   string `json:"creatorId"`
	Description string `json:"description"`
	Relaxed     bool   `json:"relaxed"`
}
