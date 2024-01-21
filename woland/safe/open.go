package safe

import (
	"encoding/json"
	"fmt"
	"sync"
	"time"

	"github.com/stregato/master/woland/core"
	"github.com/stregato/master/woland/security"
	"github.com/stregato/master/woland/sql"
	"github.com/stregato/master/woland/storage"
)

var ErrNoStoreAvailable = fmt.Errorf("no store available")

var IdentitiesFolder = ".identities"
var MaxACLFilesInZone = 4
var DefaultSyncUsersRefreshRate = 10 * time.Minute

type OpenOptions struct {
	//ResetDB cleans the DB before opening the safe
	ResetDB bool `json:"resetDB"`

	//AsyncConn connects to the stores asynchronously
	AsyncConn bool `json:"asyncConn"`

	//MinimalSyncTime is the minimal time between two syncs
	MinimalSyncTime time.Duration `json:"minimalSyncTime"`

	// OnConnected is called when the connection to the stores is established
	OnConnected chan *Safe `json:"-"`
}

func Open(currentUser security.Identity, name string, storeUrl string, creatorId string, options OpenOptions) (*Safe, error) {
	name, err := validName(name)
	if core.IsErr(err, nil, "invalid name %s: %v", name) {
		return nil, err
	}

	if options.ResetDB {
		resetSafeInDB(name)
	}

	now := core.Now()

	safeConfig, err := getSafeConfigFromDB(name, creatorId)
	if core.IsErr(err, nil, "cannot read config of safe %s from DB: %v", err) {
		return nil, err
	}

	safesCounterLock.Lock()
	s := &Safe{
		Hnd:             safesCounter,
		CurrentUser:     currentUser,
		CreatorId:       creatorId,
		Name:            name,
		Description:     safeConfig.Description,
		Keystore:        safeConfig.Keystore,
		Users:           safeConfig.Users,
		Permission:      safeConfig.Users[currentUser.Id],
		MinimalSyncTime: options.MinimalSyncTime,

		storeUrl:       storeUrl,
		storeSizes:     map[string]int64{},
		usersLock:      sync.Mutex{},
		syncUsers:      make(chan bool, 10),
		uploadFile:     make(chan UploadTask, 10),
		enforceQuota:   make(chan bool, 10),
		connect:        make(chan bool, 10),
		compactHeaders: make(chan CompactHeader, 10),
		quit:           make(chan bool, 10),
		wg:             sync.WaitGroup{},
		lastBucketSync: map[string]time.Time{},
		storeLock:      sync.Mutex{},
	}
	safesCounter++
	safesCounterLock.Unlock()

	if options.AsyncConn {
		s.connect <- true
	} else {
		err = connect(s)
		if core.IsErr(err, nil, "cannot connect to %s: %v", name) {
			return nil, err
		}
		core.Info("connected to %s in %v", name, core.Since(now))
	}

	// now = core.Now()
	// manifest, err := readManifest(name, s.PrimaryStore, creatorId)
	// if core.IsErr(err, nil, "cannot read manifest file in %s: %v", name) {
	// 	return nil, err
	// }
	// core.Info("read manifest file of %s in %v", name, core.Since(now))

	// now = core.Now()
	// users, err := getUsersFromDB(name)
	// if core.IsErr(err, nil, "cannot get users in %s: %v", name) {
	// 	return nil, err
	// }
	// s.Users = users
	// s.Permission = users[currentUser.Id]
	// s.Keystore = readKeystoreFromDB(name)

	// core.Info("read users from DB of %s in %v", name, core.Since(now))

	// err = syncStores(s)
	// if core.IsErr(err, nil, "cannot sync stores in %s: %v", name) {
	// 	return nil, err
	// }

	// now = core.Now()
	// _, err = SyncUsers(s)
	// if core.IsErr(err, nil, "cannot sync users in %s: %v", name) {
	// 	return nil, err
	// }
	// core.Info("synchorized users of %s in %v", name, core.Since(now))

	// if s.Permission == 0 {
	// 	core.Info("creating initiate file for %s", currentUser.Id)
	// 	createInitiateFile(name, s.PrimaryStore, currentUser)
	// 	return nil, fmt.Errorf("access pending")
	// }

	if s.Permission == Suspended {
		return nil, fmt.Errorf("access denied")
	}

	s.background = time.NewTicker(time.Minute)
	go backgroundJob(s)
	s.enforceQuota <- true

	core.Info("safe opened: name %s, creator %s, description %s,  #users %d, keystore %d", name,
		currentUser.Id, s.Description, len(s.Users), s.Keystore.LastKeyId)

	return s, nil
}

func connect(s *Safe) error {
	err := connectStores(s)
	if core.IsErr(err, nil, "cannot connect to stores: %v") {
		return err
	}

	err = syncStores(s)
	if core.IsErr(err, nil, "cannot sync stores of %s: %v", s.Name) {
		return err
	}

	err = syncManifest(s)
	if core.IsErr(err, nil, "cannot sync manifest of %s: %v", s.Name) {
		return err
	}
	_, err = SyncUsers(s)
	if core.IsErr(err, nil, "cannot sync users of %s: %v", s.Name) {
		return err
	}

	s.Connected = true
	return nil
}

func connectStores(s *Safe) error {
	configs, err := getStoreConfigsFromDB(s.Name)
	if core.IsErr(err, nil, "cannot get stores for safe %s: %v", s.Name, err) {
		return err
	}
	if len(configs) == 0 {
		store, err := storage.Open(s.storeUrl)
		if core.IsErr(err, nil, "cannot connect to store %s: %v", s.storeUrl, err) {
			return err
		}

		s.PrimaryStore = store
		s.SecondaryStore = store
		core.Info("connected to primary of %s for first time in %v", s.Name, core.Since(core.Now()))
		return nil
	}

	ch := make(chan storage.Store, len(configs))
	s.StoreConfigs = configs

	now := core.Now()
	for _, c := range s.StoreConfigs {
		go func(c StoreConfig) {
			store, err := storage.Open(c.Url)
			if core.IsErr(err, nil, "cannot connect to store %s: %v", c.Url, err) {
				ch <- nil
				return
			}
			if c.Primary {
				core.Info("connected to primary store %s of %s in %v", store, s.Name, core.Since(now))
				s.PrimaryStore = store
			} else {
				core.Info("connected to secondary store %s of %s in %v", store, s.Name, core.Since(now))
			}
			ch <- store
		}(c)
	}

	for i := 0; i < len(configs); i++ {
		store := <-ch
		if store == nil {
			continue
		}
		if s.PrimaryStore == store {
			core.Info("connected to primary %s in %v", s.Name, core.Since(now))
		}
		if s.SecondaryStore == nil {
			core.Info("connected to secondary %s in %v", s.Name, core.Since(now))
			s.SecondaryStore = store
		} else {
			store.Close()
		}
	}
	if s.PrimaryStore == nil {
		if s.SecondaryStore != nil {
			s.SecondaryStore.Close()
		}
		return ErrNoStoreAvailable
	}
	return nil
}

func getSafeConfigFromDB(safeName, creatorId string) (safeConfig, error) {
	var data []byte
	var config safeConfig
	err := sql.QueryRow("GET_SAFE_CONFIG", sql.Args{"safe": safeName}, &data)
	if err == sql.ErrNoRows {
		return safeConfig{
			Description: "",
			Keystore:    Keystore{},
			Users:       Users{},
		}, nil
	}

	if core.IsErr(err, nil, "cannot read config of safe %s: %v", safeName, err) {
		return config, err
	}

	err = json.Unmarshal(data, &config)
	if core.IsErr(err, nil, "cannot unmarshal config of safe %s: %v", safeName, err) {
		return config, err
	}

	return config, nil
}

func setSafeConfigToDB(safeName string, config safeConfig) error {
	data, err := json.Marshal(config)
	if core.IsErr(err, nil, "cannot marshal config of safe %s: %v", safeName) {
		return nil
	}

	_, err = sql.Exec("SET_SAFE_CONFIG", sql.Args{"safe": safeName, "config": data})
	return err
}
