package safe

import (
	"encoding/json"
	"path"
	"strings"

	"github.com/stregato/master/woland/core"
	"github.com/stregato/master/woland/sql"
	"github.com/stregato/master/woland/storage"
	"golang.org/x/crypto/blake2b"
)

func AddStore(s *Safe, storeConfig StoreConfig) error {
	data, err := json.Marshal(storeConfig)
	if core.IsErr(err, nil, "cannot marshal store %s/%s: %v", s.Name, storeConfig.Url) {
		return err
	}

	h := blake2b.Sum384([]byte(storeConfig.Url))
	n := strings.ReplaceAll(sql.EncodeBase64(h[:]), "/", "_")

	err = storage.WriteFile(s.PrimaryStore, path.Join(s.Name, ConfigFolder, n+".store"), data)
	if core.IsErr(err, nil, "cannot write store %s/%s: %v", s.Name, storeConfig.Url) {
		return err
	}

	err = setStoreInDB(s.Name, storeConfig)
	if core.IsErr(err, nil, "cannot set store %s/%s: %v", s.Name, storeConfig.Url) {
		return err
	}

	s.StoreConfigs = append(s.StoreConfigs, storeConfig)
	return nil
}

func syncStores(s *Safe) error {
	now := core.Now()

	store := s.PrimaryStore
	name := path.Join(s.Name, ConfigFolder)
	ls, err := store.ReadDir(name, storage.Filter{Suffix: ".store"})
	if core.IsErr(err, nil, "cannot read stores in %s: %v", name, err) {
		return err
	}

	for _, f := range ls {
		data, err := storage.ReadFile(s.PrimaryStore, path.Join(name, f.Name()))
		if core.IsErr(err, nil, "cannot read store %s: %v", f.Name(), err) {
			continue
		}

		var st StoreConfig
		err = json.Unmarshal(data, &st)
		if core.IsErr(err, nil, "cannot unmarshal store %s: %v", f.Name(), err) {
			continue
		}

		err = setStoreInDB(s.Name, st)
		if core.IsErr(err, nil, "cannot add store %s: %v", f.Name(), err) {
			continue
		}
		core.Info("added store %s primary %t to safe %s", st.Url, st.Primary, s.Name)
	}
	core.Info("synchorized stores of %s in %v", name, core.Since(now))

	return nil
}

func setStoreInDB(safe string, store StoreConfig) error {
	data, err := json.Marshal(store)
	if core.IsErr(err, nil, "cannot marshal store: %v", store) {
		return err
	}

	_, err = sql.Exec("SET_STORE", sql.Args{
		"safe":  safe,
		"url":   store.Url,
		"store": sql.EncodeBase64(data),
	})
	if core.IsErr(err, nil, "cannot set store %s/%s: %v", safe, store.Url) {
		return err
	}
	return nil
}

func getStoreConfigsFromDB(safe string) ([]StoreConfig, error) {
	rows, err := sql.Query("GET_STORES", sql.Args{"safe": safe})
	if core.IsErr(err, nil, "cannot get stores for safe %s: %v", safe, err) {
		return nil, err
	}
	defer rows.Close()

	stores := []StoreConfig{}
	for rows.Next() {
		var data string
		err = rows.Scan(&data)
		if core.IsErr(err, nil, "cannot scan store for safe %s: %v", safe, err) {
			return nil, err
		}
		var store StoreConfig
		err = json.Unmarshal(sql.DecodeBase64(data), &store)
		if core.IsErr(err, nil, "cannot unmarshal store options for safe %s: %v", safe, err) {
			return nil, err
		}
		stores = append(stores, store)
	}
	return stores, nil
}
