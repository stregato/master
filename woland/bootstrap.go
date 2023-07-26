package main

import (
	"os"
	"path"

	"github.com/stregato/master/woland/core"
	"github.com/stregato/master/woland/portal"
	"github.com/stregato/master/woland/sql"
)

func Start(dbPath, appPath string) error {
	err := sql.OpenDB(dbPath)
	if core.IsErr(err, "cannot open DB at %s: %v", dbPath, err) {
		return err
	}
	if appPath != "" {
		portal.CacheFolder = path.Join(appPath, ".cache")
		os.MkdirAll(portal.CacheFolder, 0755)
	}

	return nil
}

func Stop() error {
	err := sql.CloseDB()
	if core.IsErr(err, "cannot close DB: %v", err) {
		return err
	}
	return nil
}

func FactoryReset() error {
	Stop()
	err := sql.DeleteDB()
	if core.IsErr(err, "cannot delete DB: %v", err) {
		return err
	}
	return nil
}
