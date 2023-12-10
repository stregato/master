package safe

import (
	"os"
	"path/filepath"
	"sync"
	"time"

	"github.com/stregato/master/woland/security"
	"github.com/stregato/master/woland/storage"
)

var CacheFolder string
var safesCounter int
var safesCounterLock sync.Mutex

func init() {
	dataDir, err := os.UserCacheDir()
	if err == nil {
		CacheFolder = filepath.Join(dataDir, "woland", "cache")
		os.MkdirAll(CacheFolder, 0755)
	}
}

const (
	ConfigFolder   = "config"
	DataFolder     = "data"
	InitiateFolder = "initiate"
	HeaderFolder   = "h"
	BodyFolder     = "b"
	BucketFile     = ".bucket"
)

const KeySize = 32

type Keys map[uint64][]byte

type Safe struct {
	Hnd         int                 `json:"hnd"`         // Handle of the safe
	CurrentUser security.Identity   `json:"currentUser"` // Current user
	Permission  Permission          `json:"permission"`  // Permission of the current user
	Access      string              `json:"access"`      // Access token
	CreatorId   string              `json:"creatorId"`   // Creator of the safe
	Name        string              `json:"name"`        // Name of the safe including the path
	Id          uint64              `json:"id"`          // Id of the safe
	Description string              `json:"description"` // Description of the safe
	Storage     storage.Description `json:"storage"`     // Information about the store
	Quota       int64               `json:"quota"`       // Quota of the safe in bytes
	QuotaGroup  string              `json:"quotaGroup"`  // QuotaGroup is the common prefix for the safes that share the quota
	Size        int64               `json:"size"`        // Size of the safe in bytes

	keystore         Keystore           // Keystore of the safe
	store            storage.Store      // Stores of the safe
	users            Users              // Users and their permissions
	usersLock        sync.Mutex         // Lock for users
	background       *time.Ticker       // Ticker for background tasks
	syncUsers        chan bool          // Channel for syncing users
	compactHeaders   chan CompactHeader // Channel for compacting the headers
	compactHeadersWg sync.WaitGroup     // Wait group for compacting the headers
	uploadFile       chan bool          // Channel for uploading headers
	quit             chan bool          // Channel for quitting background tasks
	wg               sync.WaitGroup     // Wait group for background tasks

	//identities []security.Identity
	//	newestChangeFile     string
	//	lastIdentitiesUpdate time.Time
}

// Admins defines the users who are administrators of a box and for each those that have level2, i.e. can add or remove other administrators
type Admins map[string]Level2

type Level2 bool

// KeystoreFile is the file that contains the primary key of box encrypted for each user
type KeystoreFile struct {
	KeyId uint64            `json:"keyId"`
	Keys  map[string][]byte `json:"keys"`
}
