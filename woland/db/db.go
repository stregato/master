package db

import (
	"database/sql"

	"github.com/stregato/master/woland/safe"
)

type DB struct {
	Safe *safe.Safe
	Conn *sql.Conn
}
