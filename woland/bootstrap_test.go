package main

import (
	"os"
	"path/filepath"
	"testing"

	"github.com/stregato/master/massolit/core"
)

func TestStart(t *testing.T) {
	home, err := os.UserHomeDir()
	core.TestErr(t, err, "cannot get home dir: %v")

	dbPath := filepath.Join(home, ".local", "share", "ch.massolit.margarita", "massolit.db")
	err = Start(dbPath, "/tmp")
	core.TestErr(t, err, "cannot start: %v")
}
