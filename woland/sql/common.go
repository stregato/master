package sql

import (
	"database/sql"
	"encoding/base64"
	"fmt"
	"reflect"
	"strings"
	"time"

	"github.com/sirupsen/logrus"

	"github.com/stregato/master/woland/core"
)

var queriesCache = map[string]string{}
var stmtCache = map[string]*sql.Stmt{}
var ErrNoRows = sql.ErrNoRows

func prepareStatement(key, s string, line int) error {
	key = strings.Trim(key, " ")
	if _, ok := stmtCache[key]; ok {
		logrus.Panicf("duplicate SQL statement for key '%s' (line %d)", s, line)
		panic(key)
	}

	stmt, err := db.Prepare(s)
	if core.IsErr(err, nil, "cannot compile SQL statement '%s' (%d) '%s': %v", key, line, s) {
		return err
	}
	stmtCache[key] = stmt
	queriesCache[key] = s
	core.Info("SQL statement '%s' (%d) '%s' compiled", key, line, s)
	return nil
}

func getStatement(key string) *sql.Stmt {
	if v, ok := stmtCache[key]; ok {
		return v
	} else {
		logrus.Panicf("missing SQL statement for key '%s'", key)
		panic(key)
	}
}

type Args map[string]any

func named(m Args) []any {
	var args []any
	for k, v := range m {
		args = append(args, sql.Named(k, v))
	}
	return args
}

func trace(key string, m Args, err error) {
	if logrus.IsLevelEnabled(logrus.TraceLevel) {
		q := queriesCache[key]
		for k, v := range m {
			q = strings.ReplaceAll(q, ":"+k, fmt.Sprintf("%v", v))
		}
		logrus.Tracef("SQL: %s: %v", q, err)
	}
}

func Exec(key string, m Args) (sql.Result, error) {
	res, err := getStatement(key).Exec(named(m)...)
	trace(key, m, err)
	return res, err
}

func QueryRow(key string, m Args, dest ...any) error {
	row := getStatement(key).QueryRow(named(m)...)
	err := row.Err()
	trace(key, m, err)
	if err == nil {
		return row.Scan(dest...)
	}
	return err
}

func Query(key string, m Args) (*sql.Rows, error) {
	stmt := getStatement(key)
	rows, err := stmt.Query(named(m)...)
	trace(key, m, err)
	return rows, err
}

func QueryEx[T any](key string, m Args, f func(dest ...any) T) ([]T, error) {
	rows, err := getStatement(key).Query(named(m)...)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var res []T
	var dest []any
	t := reflect.TypeOf(f)
	for i := 0; i < t.NumIn(); i++ {
		dest = append(dest, reflect.New(t.In(i)))
	}

	for rows.Next() {
		rows.Scan(dest...)
		if err == nil {
			res = append(res, f(dest...))
		}
	}
	return res, nil
}

func EncodeBase64(data []byte) string {
	if len(data) == 0 {
		return ""
	}
	return base64.StdEncoding.EncodeToString(data)
}

func DecodeBase64(data string) []byte {
	if len(data) == 0 {
		return nil
	}
	b, err := base64.StdEncoding.DecodeString(data)
	if err != nil {
		return nil
	}
	return b
}

func EncodeTime(t time.Time) int64 {
	return t.UnixMilli()
}

func DecodeTime(v int64) time.Time {
	return time.UnixMilli(v)
}
