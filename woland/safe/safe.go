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

type StoreConfig struct {
	Name      string `json:"name"`
	Url       string `json:"url"`
	Quota     int64  `json:"quota"`
	Primary   bool   `json:"primary"`
	CreatorId string `json:"creatorId"`
}

type Safe struct {
	Hnd             int               `json:"hnd"`             // Handle of the safe
	CurrentUser     security.Identity `json:"currentUser"`     // Current user
	Permission      Permission        `json:"permission"`      // Permission of the current user
	CreatorId       string            `json:"creatorId"`       // Creator of the safe
	Name            string            `json:"name"`            // Name of the safe including the path
	Description     string            `json:"description"`     // Description of the safe
	Size            int64             `json:"size"`            // Size of the safe in bytes
	StoreConfigs    []StoreConfig     `json:"storeConfigs"`    // Stores of the safe
	MinimalSyncTime time.Duration     `json:"minimalSyncTime"` // Minimal time between syncs

	keystore             Keystore             // Keystore of the safe
	primary              storage.Store        // Primary stores of the safe
	stores               []storage.Store      // Secondary stores of the safe
	storeSizes           map[string]int64     // Sizes of the stores
	storeSizesLock       sync.Mutex           // Lock for store sizes
	users                Users                // Users and their permissions
	usersLock            sync.Mutex           // Lock for users
	background           *time.Ticker         // Ticker for background tasks
	syncUsers            chan bool            // Channel for syncing users
	compactHeaders       chan CompactHeader   // Channel for compacting the headers
	enforceQuota         chan bool            // Channel for enforcing the quota
	compactHeadersWg     sync.WaitGroup       // Wait group for compacting the headers
	uploadFile           chan UploadTask      // Channel for uploading headers
	quit                 chan bool            // Channel for quitting background tasks
	wg                   sync.WaitGroup       // Wait group for background tasks
	lastBucketSync       map[string]time.Time // Last sync time for each bucket
	lastQuotaEnforcement time.Time            // Last time the quota was checked

	//identities []security.Identity
	//	newestChangeFile     string
	//	lastIdentitiesUpdate time.Time
}

type StoreType int

const (
	StoreMaster = 1
	StoreCDN    = 2
)

// Admins defines the users who are administrators of a box and for each those that have level2, i.e. can add or remove other administrators
type Admins map[string]Level2

type Level2 bool

// KeystoreFile is the file that contains the primary key of box encrypted for each user
type KeystoreFile struct {
	KeyId uint64            `json:"keyId"`
	Keys  map[string][]byte `json:"keys"`
}
