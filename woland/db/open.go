package db

import (
	"database/sql"

	"github.com/stregato/master/woland/safe"
)

func Open(s *safe.Safe, conn *sql.Conn) (DB, error) {
	return DB{
		Safe: s,
		Conn: conn,
	}, nil
}
