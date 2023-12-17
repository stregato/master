package main

/*
#include "cfunc.h"
#include <stdlib.h>
*/
import "C"
import (
	"bytes"
	"encoding/base64"
	"encoding/json"
	"fmt"
	"sync"
	"unsafe"

	"github.com/sirupsen/logrus"

	"github.com/stregato/master/woland/core"
	"github.com/stregato/master/woland/safe"
	"github.com/stregato/master/woland/security"
	"github.com/stregato/master/woland/sql"
)

var ErrSafeNotFound = fmt.Errorf("safe not opened yet")

var safes = map[int]*safe.Safe{}
var safesSync sync.Mutex

func cResult(v any, err error) C.Result {
	var res []byte

	if err != nil {
		return C.Result{nil, C.CString(err.Error())}
	}
	if v == nil {
		return C.Result{nil, nil}
	}

	res, err = json.Marshal(v)
	if err == nil {
		return C.Result{C.CString(string(res)), nil}
	}
	return C.Result{nil, C.CString(err.Error())}
}

func cInput(err error, i *C.char, v any) error {
	if err != nil {
		return err
	}
	data := C.GoString(i)
	return json.Unmarshal([]byte(data), v)
}

func cUnmarshal(i *C.char, v any) error {
	data := C.GoString(i)
	err := json.Unmarshal([]byte(data), v)
	if core.IsErr(err, nil, "cannot unmarshal %s: %v", data) {
		return err
	}
	return nil
}

//export wlnd_start
func wlnd_start(dbPath, appPath *C.char) C.Result {
	err := Start(C.GoString(dbPath), C.GoString(appPath))
	if core.IsErr(err, nil, "cannot start: %v") {

		return cResult(nil, err)
	}

	return cResult(nil, nil)
}

//export wlnd_stop
func wlnd_stop() C.Result {
	err := Stop()
	return cResult(nil, err)
}

//export wlnd_factoryReset
func wlnd_factoryReset() C.Result {
	err := FactoryReset()
	return cResult(nil, err)
}

type configItem struct {
	S       string `json:"s,omitempty"`
	I       int64  `json:"i,omitempty"`
	B       []byte `json:"b,omitempty"`
	Missing bool   `json:"missing,omitempty"`
}

//export wlnd_getConfig
func wlnd_getConfig(node, key *C.char) C.Result {
	s, i, b, ok := sql.GetConfig(C.GoString(node), C.GoString(key))
	return cResult(configItem{S: s, I: i, B: b, Missing: !ok}, nil)
}

//export wlnd_setConfig
func wlnd_setConfig(node, key, value *C.char) C.Result {
	var item configItem
	err := cUnmarshal(value, &item)
	if core.IsErr(err, nil, "cannot unmarshal config: %v") {
		return cResult(nil, err)
	}

	err = sql.SetConfig(C.GoString(node), C.GoString(key),
		item.S, item.I, item.B)
	return cResult(nil, err)
}

//export wlnd_newIdentity
func wlnd_newIdentity(nick *C.char) C.Result {
	i, err := security.NewIdentity(C.GoString(nick))
	return cResult(i, err)
}

//export wlnd_newIdentityFromId
func wlnd_newIdentityFromId(nick, privateId *C.char) C.Result {
	i, err := security.NewIdentityFromId(C.GoString(nick), C.GoString(privateId))
	return cResult(i, err)
}

//export wlnd_setIdentity
func wlnd_setIdentity(identity *C.char) C.Result {
	var i security.Identity
	err := cUnmarshal(identity, &i)
	if core.IsErr(err, nil, "cannot unmarshal identity: %v") {
		return cResult(nil, err)
	}

	err = security.SetIdentity(i)
	return cResult(nil, err)
}

//export wlnd_getIdentity
func wlnd_getIdentity(id *C.char) C.Result {
	identity, err := security.GetIdentity(C.GoString(id))
	if core.IsErr(err, nil, "cannot get identity: %v") {
		return cResult(nil, err)
	}
	return cResult(identity, nil)
}

type Access struct {
	Name      string `json:"name"`
	Id        uint64 `json:"id"`
	CreatorId string `json:"creatorId"`
	Url       string `json:"url"`
}

// //export wlnd_encodeAccess
// func wlnd_encodeAccess(userId *C.char, access *C.char) C.Result {
// 	var a Access
// 	err := cUnmarshal(access, &a)
// 	if core.IsErr(err, nil, "cannot unmarshal token: %v") {
// 		return cResult(nil, err)
// 	}

// 	token, err := safe.EncodeAccess(C.GoString(userId), a.Name, a.Id, a.CreatorId, a.Url)
// 	if core.IsErr(err, nil, "cannot create token: %v") {
// 		return cResult(nil, err)
// 	}
// 	return cResult(token, nil)
// }

// //export wlnd_decodeAccess
// func wlnd_decodeAccess(identity *C.char, access *C.char) C.Result {
// 	var i security.Identity
// 	err := cUnmarshal(identity, &i)
// 	if core.IsErr(err, nil, "cannot unmarshal identity: %v") {
// 		return cResult(nil, err)
// 	}

// 	safeName, id, creatorId, url, err := safe.DecodeAccess(i, C.GoString(access))
// 	if core.IsErr(err, nil, "cannot transfer token: %v") {
// 		return cResult(nil, err)
// 	}
// 	return cResult(Access{
// 		Name:      safeName,
// 		Id:        id,
// 		CreatorId: creatorId,
// 		Url:       url,
// 	}, nil)
// }

//export wlnd_createSafe
func wlnd_createSafe(creator, name, url *C.char, users *C.char, createOptions *C.char) C.Result {
	var CreateOptions safe.CreateOptions
	err := cUnmarshal(createOptions, &CreateOptions)
	if core.IsErr(err, nil, "cannot unmarshal createOptions: %v") {
		return cResult(nil, err)
	}

	var i security.Identity
	err = cUnmarshal(creator, &i)
	if core.IsErr(err, nil, "cannot unmarshal identity: %v") {
		return cResult(nil, err)
	}

	var u safe.Users
	err = cUnmarshal(users, &u)
	if core.IsErr(err, nil, "cannot unmarshal users: %v") {
		return cResult(nil, err)
	}

	s, err := safe.Create(i, C.GoString(name), C.GoString(url), u, CreateOptions)
	if core.IsErr(err, nil, "cannot create safe: %v") {
		return cResult(nil, err)
	}
	safesSync.Lock()
	safes[s.Hnd] = s
	safesSync.Unlock()

	return cResult(s, err)
}

//export wlnd_addSafe
func wlnd_addSafe(name, creatorId, url *C.char, addOptions *C.char) C.Result {
	err := safe.Add(C.GoString(name), C.GoString(creatorId), C.GoString(url))
	if core.IsErr(err, nil, "cannot add safe: %v") {
		return cResult(nil, err)
	}
	return cResult(nil, nil)
}

//export wlnd_openSafe
func wlnd_openSafe(identity *C.char, name *C.char, openOptions *C.char) C.Result {
	var OpenOptions safe.OpenOptions
	err := cUnmarshal(openOptions, &OpenOptions)
	if core.IsErr(err, nil, "cannot unmarshal openOptions: %v") {
		return cResult(nil, err)
	}

	var i security.Identity
	err = cUnmarshal(identity, &i)
	if core.IsErr(err, nil, "cannot unmarshal identity: %v") {
		return cResult(nil, err)
	}

	s, err := safe.Open(i, C.GoString(name), OpenOptions)
	if core.IsErr(err, nil, "cannot open portal: %v") {
		return cResult(nil, err)
	}
	safesSync.Lock()
	safes[s.Hnd] = s
	safesSync.Unlock()

	return cResult(s, err)
}

//export wlnd_closeSafe
func wlnd_closeSafe(hnd C.int) C.Result {
	safesSync.Lock()
	defer safesSync.Unlock()
	s, ok := safes[int(hnd)]
	if !ok {
		return cResult(nil, ErrSafeNotFound)
	}
	safe.Close(s)
	delete(safes, int(hnd))
	return cResult(nil, nil)
}

//export wlnd_syncBucket
func wlnd_syncBucket(hnd C.int, bucket, syncOptions *C.char) C.Result {
	safesSync.Lock()
	s, ok := safes[int(hnd)]
	safesSync.Unlock()
	if !ok {
		return cResult(nil, ErrSafeNotFound)
	}
	var options safe.SyncOptions
	err := cUnmarshal(syncOptions, &options)
	if core.IsErr(err, nil, "cannot unmarshal syncOptions: %v") {
		return cResult(nil, err)
	}

	changes, err := safe.SyncBucket(s, C.GoString(bucket), options, nil)
	if core.IsErr(err, nil, "cannot sync safe: %v") {
		return cResult(nil, err)
	}
	return cResult(changes, nil)
}

//export wlnd_syncUsers
func wlnd_syncUsers(hnd C.int) C.Result {
	safesSync.Lock()
	s, ok := safes[int(hnd)]
	safesSync.Unlock()
	if !ok {
		return cResult(nil, ErrSafeNotFound)
	}

	changes, err := safe.SyncUsers(s)
	if core.IsErr(err, nil, "cannot sync safe: %v") {
		return cResult(nil, err)
	}
	return cResult(changes, nil)
}

//export wlnd_listFiles
func wlnd_listFiles(hnd C.int, dir, listOptions *C.char) C.Result {
	safesSync.Lock()
	s, ok := safes[int(hnd)]
	safesSync.Unlock()
	if !ok {
		return cResult(nil, ErrSafeNotFound)
	}
	var options safe.ListOptions
	err := cUnmarshal(listOptions, &options)
	if core.IsErr(err, nil, "cannot unmarshal listOptions %s: %v", C.GoString(listOptions)) {
		return cResult(nil, err)
	}

	headers, err := safe.ListFiles(s, C.GoString(dir), options)
	return cResult(headers, err)
}

//export wlnd_listDirs
func wlnd_listDirs(hnd C.int, bucket *C.char, listDirsOptions *C.char) C.Result {
	safesSync.Lock()
	s, ok := safes[int(hnd)]
	safesSync.Unlock()
	if !ok {
		return cResult(nil, ErrSafeNotFound)
	}
	var options safe.ListDirsOptions
	err := cUnmarshal(listDirsOptions, &options)
	if core.IsErr(err, nil, "cannot unmarshal listDirsOptions %s: %v", C.GoString(listDirsOptions)) {
		return cResult(nil, err)
	}

	dirs, err := safe.ListDirs(s, C.GoString(bucket), options)
	return cResult(dirs, err)
}

type CReader struct {
	R *C.Reader
}

func (r CReader) Read(p []byte) (n int, err error) {
	s := C.callRead(r.R, unsafe.Pointer(&p[0]), C.int(len(p)))
	if s < 0 {
		return 0, fmt.Errorf("cannot read")
	}
	return int(s), nil
}

func (r CReader) Seek(offset int64, whence int) (int64, error) {
	s := C.callSeek(r.R, C.int(offset), C.int(whence))
	if s < 0 {
		return 0, fmt.Errorf("cannot seek")
	}
	return int64(s), nil
}

type CWriter struct {
	W *C.Writer
}

func (w CWriter) Write(p []byte) (n int, err error) {
	s := C.callWrite(w.W, unsafe.Pointer(&p[0]), C.int(len(p)))
	if s < 0 {
		return 0, fmt.Errorf("cannot write")
	}
	return int(s), nil
}

//export wlnd_putData
func wlnd_putData(hnd C.int, bucket, name *C.char, r *C.Reader, putOptions *C.char) C.Result {
	safesSync.Lock()
	s, ok := safes[int(hnd)]
	safesSync.Unlock()
	if !ok {
		return cResult(nil, ErrSafeNotFound)
	}

	var options safe.PutOptions
	err := cUnmarshal(putOptions, &options)
	if core.IsErr(err, nil, "cannot unmarshal putOptions: %v") {
		return cResult(nil, err)
	}

	header, err := safe.Put(s, C.GoString(bucket), C.GoString(name), CReader{r}, options, nil)
	if core.IsErr(err, nil, "cannot put file: %v") {
		return cResult(nil, err)
	}

	return cResult(header, nil)
}

//export wlnd_putCString
func wlnd_putCString(hnd C.int, bucket, name, data *C.char, putOptions *C.char) C.Result {

	safesSync.Lock()
	s, ok := safes[int(hnd)]
	safesSync.Unlock()
	if !ok {
		return cResult(nil, ErrSafeNotFound)
	}

	var options safe.PutOptions
	err := cUnmarshal(putOptions, &options)
	if core.IsErr(err, nil, "cannot unmarshal putOptions: %v") {
		return cResult(nil, err)
	}

	bytes, err := base64.StdEncoding.DecodeString(C.GoString(data))
	if core.IsErr(err, nil, "cannot decode base64: %v") {
		return cResult(nil, err)
	}

	r := core.NewBytesReader(bytes)

	header, err := safe.Put(s, C.GoString(bucket), C.GoString(name), r, options, nil)
	if core.IsErr(err, nil, "cannot put file: %v") {
		return cResult(nil, err)
	}
	return cResult(header, nil)
}

//export wlnd_putFile
func wlnd_putFile(hnd C.int, bucket, name *C.char, sourceFile *C.char, putOptions *C.char) C.Result {
	safesSync.Lock()
	s, ok := safes[int(hnd)]
	safesSync.Unlock()
	if !ok {
		return cResult(nil, ErrSafeNotFound)
	}

	var options safe.PutOptions
	err := cUnmarshal(putOptions, &options)
	if core.IsErr(err, nil, "cannot unmarshal putOptions: %v") {
		return cResult(nil, err)
	}

	header, err := safe.Put(s, C.GoString(bucket), C.GoString(name), C.GoString(sourceFile), options, nil)
	if core.IsErr(err, nil, "cannot put file: %v") {
		return cResult(nil, err)
	}
	return cResult(header, nil)
}

//export wlnd_getData
func wlnd_getData(hnd C.int, bucket, name *C.char, w *C.Writer, getOptions *C.char) C.Result {
	safesSync.Lock()
	s, ok := safes[int(hnd)]
	safesSync.Unlock()
	if !ok {
		return cResult(nil, ErrSafeNotFound)
	}

	var options safe.GetOptions
	err := cUnmarshal(getOptions, &options)
	if core.IsErr(err, nil, "cannot unmarshal getOptions: %v") {
		return cResult(nil, err)
	}

	header, err := safe.Get(s, C.GoString(bucket), C.GoString(name), CWriter{w}, options)
	if core.IsErr(err, nil, "cannot get file: %v") {
		return cResult(nil, err)
	}

	return cResult(header, nil)
}

//export wlnd_getCString
func wlnd_getCString(hnd C.int, bucket, name, getOptions *C.char) C.Result {
	safesSync.Lock()
	s, ok := safes[int(hnd)]
	safesSync.Unlock()
	if !ok {
		return cResult(nil, ErrSafeNotFound)
	}

	var options safe.GetOptions
	err := cUnmarshal(getOptions, &options)
	if core.IsErr(err, nil, "cannot unmarshal getOptions: %v") {
		return cResult(nil, err)
	}

	buf := bytes.Buffer{}
	_, err = safe.Get(s, C.GoString(bucket), C.GoString(name), &buf, options)
	if core.IsErr(err, nil, "cannot get file: %v") {
		return cResult(nil, err)
	}

	r := base64.StdEncoding.EncodeToString(buf.Bytes())
	return cResult(r, nil)
}

//export wlnd_getFile
func wlnd_getFile(hnd C.int, bucket, name, destFile, getOptions *C.char) C.Result {
	safesSync.Lock()
	s, ok := safes[int(hnd)]
	safesSync.Unlock()
	if !ok {
		return cResult(nil, ErrSafeNotFound)
	}

	var options safe.GetOptions
	err := cUnmarshal(getOptions, &options)
	if core.IsErr(err, nil, "cannot unmarshal getOptions: %v") {
		return cResult(nil, err)
	}

	header, err := safe.Get(s, C.GoString(bucket), C.GoString(name), C.GoString(destFile), options)
	if core.IsErr(err, nil, "cannot get file: %v") {
		return cResult(nil, err)
	}
	return cResult(header, nil)
}

//export wlnd_deleteFile
func wlnd_deleteFile(hnd C.int, bucket *C.char, fileId C.long) C.Result {
	safesSync.Lock()
	s, ok := safes[int(hnd)]
	safesSync.Unlock()
	if !ok {
		return cResult(nil, ErrSafeNotFound)
	}
	err := safe.DeleteFile(s, C.GoString(bucket), uint64(fileId))
	if core.IsErr(err, nil, "cannot delete file: %v") {
		return cResult(nil, err)
	}
	return cResult(nil, nil)
}

//export wlnd_setUsers
func wlnd_setUsers(hnd C.int, users *C.char, setUsersOptions *C.char) C.Result {
	safesSync.Lock()
	s, ok := safes[int(hnd)]
	safesSync.Unlock()
	if !ok {
		return cResult(nil, ErrSafeNotFound)
	}

	var users_ safe.Users
	err := cUnmarshal(users, &users_)
	if core.IsErr(err, nil, "cannot unmarshal users: %v") {
		return cResult(nil, err)
	}

	var options safe.SetUsersOptions
	err = cUnmarshal(setUsersOptions, &options)
	if core.IsErr(err, nil, "cannot unmarshal setUsersOptions: %v") {
		return cResult(nil, err)
	}

	err = safe.SetUsers(s, users_, options)
	if core.IsErr(err, nil, "cannot set users: %v") {
		return cResult(nil, err)
	}
	return cResult(nil, nil)
}

//export wlnd_getUsers
func wlnd_getUsers(hnd C.int) C.Result {
	safesSync.Lock()
	s, ok := safes[int(hnd)]
	safesSync.Unlock()
	if !ok {
		return cResult(nil, ErrSafeNotFound)
	}

	users, err := safe.GetUsers(s)
	if core.IsErr(err, nil, "cannot get users: %v") {
		return cResult(nil, err)
	}
	return cResult(users, nil)
}

//export wlnd_getInitiates
func wlnd_getInitiates(hnd C.int) C.Result {
	safesSync.Lock()
	s, ok := safes[int(hnd)]
	safesSync.Unlock()
	if !ok {
		return cResult(nil, ErrSafeNotFound)
	}

	initiates, err := safe.GetInitiates(s)
	if core.IsErr(err, nil, "cannot get initiates: %v") {
		return cResult(nil, err)
	}
	return cResult(initiates, nil)
}

// //export checkForUpdates
// func checkForUpdates(hnd C.int, dir *C.char, after *C.char, depth C.int) C.Result {
// 	safesSync.Lock()
// 	s, ok := safes[int(hnd)]
// 	safesSync.Unlock()
// 	if !ok {
// 		return cResult(nil, ErrSafeNotFound)
// 	}
// 	a, err := time.Parse(time.RFC3339, C.GoString(after))
// 	if core.IsErr(err, nil, "cannot parse time: %v") {
// 		return cResult(nil, err)
// 	}

// 	updates, err := safe.CheckForUpdates(s, C.GoString(dir), a, int(depth))
// 	if core.IsErr(err, nil, "cannot check for updates: %v") {
// 		return cResult(nil, err)
// 	}
// 	return cResult(updates, nil)
// }

//export wlnd_getAllIdentities
func wlnd_getAllIdentities() C.Result {
	identities, err := security.GetIdentities()
	if err != nil {
		return cResult(nil, err)
	}
	return cResult(identities, nil)
}

//export wlnd_getLogs
func wlnd_getLogs() C.Result {
	return cResult(core.RecentLog, nil)
}

//export wlnd_setLogLevel
func wlnd_setLogLevel(level C.int) C.Result {
	logrus.SetLevel(logrus.Level(level))
	core.Info("log level set to %d", level)
	return cResult(nil, nil)
}
