package main

import (
	"os"
	"path/filepath"
	"testing"

	"github.com/stregato/master/woland/core"
)

func TestStart(t *testing.T) {
	home, err := os.UserHomeDir()
	core.TestErr(t, err, "cannot get home dir: %v")

	dbPath := filepath.Join(home, ".local", "share", "ch.woland.margarita", "woland.db")
	err = Start(dbPath, "/tmp")
	core.TestErr(t, err, "cannot start: %v")
}
