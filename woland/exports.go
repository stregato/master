package main

/*
typedef struct Result{
    char* res;
	char* err;
} Result;

typedef struct App {
	void (*feed)(char* name, char* data, int eof);
} App;

typedef int (*ReadFn)(char* data, int size);
typedef int (*SeekFn)(int offset, int whence);
typedef int (*WriteFn)(char* data, int size);

int callRead(ReadFn fn, char* data, int size) {
	return fn(data, size);
}
int callSeek(SeekFn fn, int offset, int whence) {
	return fn(offset, whence);
}
int callWrite(WriteFn fn, char* data, int size) {
	return fn(data, size);
}

#include <stdlib.h>
*/
//#cgo LDFLAGS: -Wl,--allow-multiple-definition
import "C"
import (
	"encoding/json"
	"fmt"
	"unsafe"

	"github.com/stregato/master/woland/core"
	"github.com/stregato/master/woland/safe"
	"github.com/stregato/master/woland/security"
	"github.com/stregato/master/woland/sql"
)

var ErrSafeNotFound = fmt.Errorf("safe not found")
var safes = map[string]*safe.Safe{}

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
	return json.Unmarshal([]byte(data), v)

}

//export start
func start(dbPath *C.char, cachePath *C.char, availableBandwith *C.char) C.Result {
	p := C.GoString(dbPath)
	return cResult(nil, Start(p))
}

//export stop
func stop() C.Result {
	err := Stop()
	return cResult(nil, err)
}

//export factoryReset
func factoryReset() C.Result {
	err := FactoryReset()
	return cResult(nil, err)
}

type getConfigResult struct {
	S string
	I int64
	B []byte
}

//export getConfig
func getConfig(node, key *C.char) C.Result {
	s, i, b, ok := sql.GetConfig(C.GoString(node), C.GoString(key))
	if ok {
		return cResult(getConfigResult{S: s, I: i, B: b}, nil)
	} else {
		return cResult(nil, fmt.Errorf("cannot get config"))
	}
}

//export setConfig
func setConfig(node, key, s *C.char, i C.int, b *C.char) C.Result {
	err := sql.SetConfig(C.GoString(node), C.GoString(key),
		C.GoString(s), int64(i), []byte(C.GoString(b)))
	return cResult(nil, err)
}

//export newIdentity
func newIdentity(nick *C.char) C.Result {
	i, err := security.NewIdentity(C.GoString(nick))
	return cResult(i, err)
}

//export setIdentity
func setIdentity(identity *C.char) C.Result {
	var i security.Identity
	err := cUnmarshal(identity, &i)
	if core.IsErr(err, "cannot unmarshal identity: %v") {
		return cResult(nil, err)
	}

	err = security.SetIdentity(i)
	return cResult(nil, err)
}

//export getIdentity
func getIdentity(id *C.char) C.Result {
	identity, ok, err := security.GetIdentity(C.GoString(id))
	if ok {
		return cResult(identity, err)
	} else {
		return cResult(nil, err)
	}
}

//export open
func open(id *C.char, token *C.char, openOptions *C.char) C.Result {
	var OpenOptions safe.OpenOptions
	err := cUnmarshal(openOptions, &OpenOptions)
	if core.IsErr(err, "cannot unmarshal openOptions: %v") {
		return cResult(nil, err)
	}

	safe, err := safe.Open(C.GoString(id), C.GoString(token), OpenOptions)
	if core.IsErr(err, "cannot open safe: %v") {
		return cResult(nil, err)
	}
	safes[C.GoString(id)] = safe
	return cResult(safe, err)
}

//export close
func close(safeName *C.char) C.Result {
	s, ok := safes[C.GoString(safeName)]
	if !ok {
		return cResult(nil, ErrSafeNotFound)
	}
	s.Close()
	delete(safes, C.GoString(safeName))
	return cResult(nil, nil)
}

//export list
func list(safeName, zoneName *C.char) C.Result {
	s, ok := safes[C.GoString(safeName)]
	if !ok {
		return cResult(nil, ErrSafeNotFound)
	}
	var listOptions safe.ListOptions
	err := cUnmarshal(zoneName, &listOptions)
	if core.IsErr(err, "cannot unmarshal listOptions: %v") {
		return cResult(nil, err)
	}

	headers, err := s.List(C.GoString(zoneName), safe.ListOptions{})
	return cResult(headers, err)
}

type CFile struct {
	read  C.ReadFn
	seek  C.SeekFn
	write C.WriteFn
}

func (f CFile) Read(p []byte) (n int, err error) {
	s := C.callRead(f.read, (*C.char)(unsafe.Pointer(&p[0])), C.int(len(p)))
	if s < 0 {
		return 0, fmt.Errorf("cannot read")
	}
	return int(s), nil
}

func (f CFile) Seek(offset int64, whence int) (int64, error) {
	s := C.callSeek(f.seek, C.int(offset), C.int(whence))
	if s < 0 {
		return 0, fmt.Errorf("cannot seek")
	}
	return int64(s), nil
}

func (f CFile) Write(p []byte) (n int, err error) {
	s := C.callWrite(f.write, (*C.char)(unsafe.Pointer(&p[0])), C.int(len(p)))
	if s < 0 {
		return 0, fmt.Errorf("cannot write")
	}
	return int(s), nil
}

//export put
func put(safeName, zoneName, name *C.char, read C.ReadFn, seek C.SeekFn, putOptions *C.char) C.Result {
	s, ok := safes[C.GoString(safeName)]
	if !ok {
		return cResult(nil, ErrSafeNotFound)
	}

	var options safe.PutOptions
	err := cUnmarshal(putOptions, &options)
	if core.IsErr(err, "cannot unmarshal putOptions: %v") {
		return cResult(nil, err)
	}

	f := CFile{read, seek, nil}
	err = s.Put(C.GoString(zoneName), C.GoString(name), f, options)
	if core.IsErr(err, "cannot put file: %v") {
		return cResult(nil, err)
	}

	return cResult(nil, nil)
}

//export get
func get(safeName, zoneName, name *C.char, write C.WriteFn, getOptions *C.char) C.Result {
	s, ok := safes[C.GoString(safeName)]
	if !ok {
		return cResult(nil, ErrSafeNotFound)
	}

	var options safe.GetOptions
	err := cUnmarshal(getOptions, &options)
	if core.IsErr(err, "cannot unmarshal getOptions: %v") {
		return cResult(nil, err)
	}

	f := CFile{nil, nil, write}
	err = s.Get(C.GoString(zoneName), C.GoString(name), f, options)
	if core.IsErr(err, "cannot get file: %v") {
		return cResult(nil, err)
	}

	return cResult(nil, nil)
}

//export createZone
func createZone(safeName, zoneName *C.char, users *C.char) C.Result {
	s, ok := safes[C.GoString(safeName)]
	if !ok {
		return cResult(nil, ErrSafeNotFound)
	}

	var users_ safe.Users
	err := cUnmarshal(users, &users_)
	if core.IsErr(err, "cannot unmarshal users: %v") {
		return cResult(nil, err)
	}

	err = s.CreateZone(C.GoString(zoneName), users_)
	if core.IsErr(err, "cannot create zone: %v") {
		return cResult(nil, err)
	}
	return cResult(nil, nil)
}

//export zones
func zones(safeName *C.char) C.Result {
	s, ok := safes[C.GoString(safeName)]
	if !ok {
		return cResult(nil, ErrSafeNotFound)
	}

	zones, err := s.Zones()
	if core.IsErr(err, "cannot get zones: %v") {
		return cResult(nil, err)
	}
	return cResult(zones, nil)
}

//export setUsers
func setUsers(safeName, zoneName *C.char, users *C.char) C.Result {
	s, ok := safes[C.GoString(safeName)]
	if !ok {
		return cResult(nil, ErrSafeNotFound)
	}

	var users_ safe.Users
	err := cUnmarshal(users, &users_)
	if core.IsErr(err, "cannot unmarshal users: %v") {
		return cResult(nil, err)
	}

	err = s.SetUsers(C.GoString(zoneName), users_)
	if core.IsErr(err, "cannot set users: %v") {
		return cResult(nil, err)
	}
	return cResult(nil, nil)
}
