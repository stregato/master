package main

import (
	"github.com/stregato/master/woland/core"
	"github.com/stregato/master/woland/safe"
	"github.com/stregato/master/woland/sql"
)

func Start(dbPath string) error {
	err := sql.OpenDB(dbPath)
	if core.IsErr(err, "cannot open DB at %s: %v", dbPath, err) {
		return err
	}

	s, _, _, ok := sql.GetConfig("config", "cacheFolder")
	if ok {
		safe.ConfigFolder = s
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
