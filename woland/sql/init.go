package sql

import (
	"database/sql"
	_ "embed"
	"errors"
	"os"
	"strings"

	_ "github.com/mattn/go-sqlite3"
	"github.com/sirupsen/logrus"

	"github.com/stregato/master/woland/core"
)

//go:embed sqlite.sql
var InitDDL string

var db *sql.DB
var DbPath string

func createTables() error {
	parts := strings.Split(InitDDL, "\n\n")

	for line, part := range parts {
		if strings.Trim(part, " ") == "" {
			continue
		}

		if !strings.HasPrefix(part, "-- ") {
			logrus.Errorf("unexpected break without a comment in '%s'", part)
		}

		cr := strings.Index(part, "\n")
		if cr == -1 {
			logrus.Error("invalid comment without CR")
			return os.ErrInvalid
		}
		key, ql := part[3:cr], part[cr+1:]

		if strings.HasPrefix(key, "INIT") {
			_, err := db.Exec(ql)
			if err != nil {
				logrus.Errorf("cannot execute SQL Init stmt (line %d) '%s': %v", line, ql, err)
				return err
			}
		} else {
			err := prepareStatement(key, ql, line)
			if err != nil {
				return err
			}
		}
	}
	return nil
}

// LoadSQLFromFile loads the sql queries from the provided file path. It panics in case the file cannot be loaded
func LoadSQLFromFile(name string) error {
	ddl, err := os.ReadFile(name)
	if core.IsErr(err, "cannot load SQL queries from %s: %v", name) {
		return err
	}

	InitDDL = string(ddl)
	return nil
}

var MemoryDB = ":memory:"

func OpenDB(dbPath string) error {
	if db != nil {
		return nil
	}

	DbPath = dbPath
	if DbPath != MemoryDB {
		_, err := os.Stat(DbPath)
		if errors.Is(err, os.ErrNotExist) {
			err := os.WriteFile(dbPath, []byte{}, 0644)
			if err != nil {
				logrus.Errorf("cannot create SQLite db in %s: %v", DbPath, err)
				return err
			}

		} else if err != nil {
			logrus.Errorf("cannot access SQLite db file %s: %v", DbPath, err)
		}
	}

	var err error
	db, err = sql.Open("sqlite3", DbPath)
	if err != nil {
		logrus.Errorf("cannot open SQLite db in %s: %v", DbPath, err)
		return err
	}

	return createTables()
}

func CloseDB() error {
	if db == nil {
		return os.ErrClosed
	}
	err := db.Close()
	db = nil
	queriesCache = map[string]string{}
	stmtCache = map[string]*sql.Stmt{}
	return err
}

func DeleteDB() error {
	return os.Remove(DbPath)
}
