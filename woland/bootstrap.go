package main

import (
	"os"
	"path"

	"github.com/stregato/master/woland/core"
	"github.com/stregato/master/woland/safe"
	"github.com/stregato/master/woland/sql"
)

func Start(dbPath, appPath string) error {
	err := sql.OpenDB(dbPath)
	if core.IsErr(err, nil, "cannot open DB at %s: %v", dbPath, err) {
		return err
	}
	if appPath != "" {
		safe.CacheFolder = path.Join(appPath, ".cache")
		os.MkdirAll(safe.CacheFolder, 0755)
	}

	return nil
}

func Stop() error {
	err := sql.CloseDB()
	if core.IsErr(err, nil, "cannot close DB: %v", err) {
		return err
	}
	return nil
}

func FactoryReset() error {
	err := sql.DeleteDB(sql.DbPath)
	if core.IsErr(err, nil, "cannot delete DB: %v", err) {
		return err
	}
	core.Info("DB %s deleted", sql.DbPath)
	return nil
}
