package core

import (
	"fmt"
	"path"
	"path/filepath"
	"runtime"
	"testing"

	"github.com/sirupsen/logrus"
)

var ErrNotInitialized = fmt.Errorf("woland not initialized")
var ErrNoDriver = fmt.Errorf("no driver found for the provided configuration")
var ErrInvalidSignature = fmt.Errorf("signature does not match the user id")
var ErrInvalidSize = fmt.Errorf("provided slice has not enough data")
var ErrInvalidVersion = fmt.Errorf("version of protocol is not compatible")
var ErrInvalidChangeFilePath = fmt.Errorf("a change file is not in a valid Woland folder")
var ErrInvalidFilePath = fmt.Errorf("a file is not in a valid Woland folder")
var ErrNoExchange = fmt.Errorf("no exchange reachable for the domain")
var ErrNotAuthorized = fmt.Errorf("user is not authorized in the domain")
var ErrInvalidId = fmt.Errorf("the id is invalid")

var RecentLog []string
var MaxRecentErrors = 4096
var MaxStacktraceOut = 5

func IsErr(err error, msg string, args ...interface{}) bool {
	msg = getErrMsg(err, msg, args...)
	if msg != "" {
		logrus.Error(msg)
		if len(RecentLog) >= MaxRecentErrors {
			RecentLog = RecentLog[1 : MaxRecentErrors-1]
		}
		RecentLog = append(RecentLog, fmt.Sprintf("ERRO: %s", msg))
		return true
	}
	return false
}

func IsWarn(err error, msg string, args ...interface{}) bool {
	msg = getErrMsg(err, msg, args...)
	if msg != "" {
		logrus.Warn(msg)
		if len(RecentLog) >= MaxRecentErrors {
			RecentLog = RecentLog[1 : MaxRecentErrors-1]
		}
		RecentLog = append(RecentLog, fmt.Sprintf("ERRO: %s", msg))
		return true
	}
	return false
}

func TestErr(t *testing.T, err error, msg string, args ...interface{}) {
	msg = getErrMsg(err, msg, args...)
	if msg != "" {
		t.Fatalf(msg)
	}
}

func getErrMsg(err error, msg string, args ...interface{}) string {
	if err != nil {
		args = append(args, err)
		msg = fmt.Sprintf(msg, args...)
		pc, file, no, ok := runtime.Caller(1)
		if ok {
			name := ""
			details := runtime.FuncForPC(pc)
			if details != nil {
				name = path.Base(details.Name())
			}
			msg = fmt.Sprintf("%s[%s:%d] - %s", name, filepath.Base(file), no, msg)
			for i := 2; i < MaxStacktraceOut; i++ {
				pc, file, no, ok := runtime.Caller(i)
				details := runtime.FuncForPC(pc)
				if ok && details != nil {
					msg = fmt.Sprintf("%s\n\t%s[%s:%d]", msg, path.Base(details.Name()), filepath.Base(file), no)
				}
			}
		}
		return msg
	}
	return ""
}

func FatalIf(err error, msg string, args ...interface{}) {
	if err != nil {
		args = append(args, err)
		logrus.Fatalf(msg, args...)
		panic(err)
	}
}
