package main

/*
typedef struct Result{
    char* res;
	char* err;
} Result;

typedef struct App {
	void (*feed)(char* name, char* data, int eof);
} App;

typedef struct Reader {
	void* fd;
	int (*read)(void* fd, void* data, int size);
	int (*seek)(void* fd, int offset, int whence);
	int (*write)(void* fd, void* data, int size);
} Reader;

int callRead(Reader* r, void* data, int size) {
	return r->read(r->fd, data, size);
}
int callSeek(Reader *r, int offset, int whence) {
	return r->seek(r->fd, offset, whence);
}

typedef struct Writer {
	void* fd;
	int (*write)(void* fd, void* data, int size);
} Writer;

int callWrite(Writer *w, void* data, int size) {
	return w->write(w->fd, data, size);
}

#include <stdlib.h>
*/
//#cgo LDFLAGS: -Wl,--allow-multiple-definition
import "C"
import (
	"bytes"
	"encoding/base64"
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"unsafe"

	"github.com/sirupsen/logrus"

	"github.com/stregato/master/woland/core"
	"github.com/stregato/master/woland/safe"
	"github.com/stregato/master/woland/security"
	"github.com/stregato/master/woland/sql"
)

var ErrSafeNotFound = fmt.Errorf("portal not found")
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
	err := json.Unmarshal([]byte(data), v)
	if core.IsErr(err, nil, "cannot unmarshal %s: %v", data) {
		return err
	}
	return nil
}

//export start
func start(dbPath, appPath *C.char) C.Result {
	err := Start(C.GoString(dbPath), C.GoString(appPath))
	if core.IsErr(err, nil, "cannot start: %v") {
		return cResult(nil, err)
	}
	return cResult(nil, nil)
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

type configItem struct {
	S       string `json:"s,omitempty"`
	I       int64  `json:"i,omitempty"`
	B       []byte `json:"b,omitempty"`
	Missing bool   `json:"missing,omitempty"`
}

//export getConfig
func getConfig(node, key *C.char) C.Result {
	s, i, b, ok := sql.GetConfig(C.GoString(node), C.GoString(key))
	return cResult(configItem{S: s, I: i, B: b, Missing: !ok}, nil)
}

//export setConfig
func setConfig(node, key, value *C.char) C.Result {
	var item configItem
	err := cUnmarshal(value, &item)
	if core.IsErr(err, nil, "cannot unmarshal config: %v") {
		return cResult(nil, err)
	}

	err = sql.SetConfig(C.GoString(node), C.GoString(key),
		item.S, item.I, item.B)
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
	if core.IsErr(err, nil, "cannot unmarshal identity: %v") {
		return cResult(nil, err)
	}

	err = security.SetIdentity(i)
	return cResult(nil, err)
}

//export getIdentity
func getIdentity(id *C.char) C.Result {
	identity, err := security.GetIdentity(C.GoString(id))
	if core.IsErr(err, nil, "cannot get identity: %v") {
		return cResult(nil, err)
	}
	return cResult(identity, nil)
}

//export encodeAccess
func encodeAccess(userId *C.char, safeName *C.char, creatorId *C.char, aesKey *C.char, urls *C.char) C.Result {
	var urls_ []string
	err := cUnmarshal(urls, &urls_)
	if core.IsErr(err, nil, "cannot unmarshal urls: %v") {
		return cResult(nil, err)
	}
	token, err := safe.EncodeAccess(C.GoString(userId), C.GoString(safeName), C.GoString(creatorId),
		[]byte(C.GoString(aesKey)), urls_...)
	if core.IsErr(err, nil, "cannot create token: %v") {
		return cResult(nil, err)
	}
	return cResult(token, nil)
}

type decodedToken struct {
	SafeName  string   `json:"safeName"`
	CreatorId string   `json:"creatorId"`
	AesKey    []byte   `json:"aesKey"`
	Urls      []string `json:"urls"`
}

//export decodeAccess
func decodeAccess(identity *C.char, token *C.char) C.Result {
	var i security.Identity
	err := cUnmarshal(identity, &i)
	if core.IsErr(err, nil, "cannot unmarshal identity: %v") {
		return cResult(nil, err)
	}

	safeName, creatorId, aesKey, urls, err := safe.DecodeAccess(i, C.GoString(token))
	if core.IsErr(err, nil, "cannot transfer token: %v") {
		return cResult(nil, err)
	}
	return cResult(decodedToken{
		SafeName:  safeName,
		CreatorId: creatorId,
		AesKey:    aesKey,
		Urls:      urls,
	}, nil)
}

//export createSafe
func createSafe(identity *C.char, token *C.char, createOptions *C.char) C.Result {
	var CreateOptions safe.CreateOptions
	err := cUnmarshal(createOptions, &CreateOptions)
	if core.IsErr(err, nil, "cannot unmarshal createOptions: %v") {
		return cResult(nil, err)
	}

	var i security.Identity
	err = cUnmarshal(identity, &i)
	if core.IsErr(err, nil, "cannot unmarshal identity: %v") {
		return cResult(nil, err)
	}

	s, err := safe.Create(i, C.GoString(token), CreateOptions)
	if core.IsErr(err, nil, "cannot create portal: %v") {
		return cResult(nil, err)
	}
	safes[s.Name] = s
	return cResult(s, err)
}

//export openSafe
func openSafe(identity *C.char, token *C.char, openOptions *C.char) C.Result {
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

	s, err := safe.Open(i, C.GoString(token), OpenOptions)
	if core.IsErr(err, nil, "cannot open portal: %v") {
		return cResult(nil, err)
	}
	safes[s.Name] = s
	return cResult(s, err)
}

//export closeSafe
func closeSafe(safeName *C.char) C.Result {
	s, ok := safes[C.GoString(safeName)]
	if !ok {
		return cResult(nil, ErrSafeNotFound)
	}
	safe.Close(s)
	delete(safes, C.GoString(safeName))
	return cResult(nil, nil)
}

//export listFiles
func listFiles(safeName, dir, listOptions *C.char) C.Result {
	s, ok := safes[C.GoString(safeName)]
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

//export listDirs
func listDirs(safeName, dir *C.char, listDirsOptions *C.char) C.Result {
	s, ok := safes[C.GoString(safeName)]
	if !ok {
		return cResult(nil, ErrSafeNotFound)
	}
	var options safe.ListDirsOptions
	err := cUnmarshal(listDirsOptions, &options)
	if core.IsErr(err, nil, "cannot unmarshal listDirsOptions %s: %v", C.GoString(listDirsOptions)) {
		return cResult(nil, err)
	}

	dirs, err := safe.ListDirs(s, C.GoString(dir), options)
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

//export putData
func putData(safeName, name *C.char, r *C.Reader, putOptions *C.char) C.Result {
	s, ok := safes[C.GoString(safeName)]
	if !ok {
		return cResult(nil, ErrSafeNotFound)
	}

	var options safe.PutOptions
	err := cUnmarshal(putOptions, &options)
	if core.IsErr(err, nil, "cannot unmarshal putOptions: %v") {
		return cResult(nil, err)
	}

	header, err := safe.Put(s, C.GoString(name), CReader{r}, options)
	if core.IsErr(err, nil, "cannot put file: %v") {
		return cResult(nil, err)
	}

	return cResult(header, nil)
}

//export putCString
func putCString(safeName, name, data *C.char,
	putOptions *C.char) C.Result {

	s, ok := safes[C.GoString(safeName)]
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

	header, err := safe.Put(s, C.GoString(name), r, options)
	if core.IsErr(err, nil, "cannot put file: %v") {
		return cResult(nil, err)
	}
	return cResult(header, nil)
}

//export putFile
func putFile(safeName, name *C.char, sourceFile *C.char, putOptions *C.char) C.Result {
	s, ok := safes[C.GoString(safeName)]
	if !ok {
		return cResult(nil, ErrSafeNotFound)
	}

	var options safe.PutOptions
	err := cUnmarshal(putOptions, &options)
	if core.IsErr(err, nil, "cannot unmarshal putOptions: %v") {
		return cResult(nil, err)
	}

	r, err := os.Open(C.GoString(sourceFile))
	if core.IsErr(err, nil, "cannot open file: %v") {
		return cResult(nil, err)
	}

	header, err := safe.Put(s, C.GoString(name), r, options)
	if core.IsErr(err, nil, "cannot put file: %v") {
		return cResult(nil, err)
	}
	return cResult(header, nil)
}

//export getData
func getData(safeName, name *C.char, w *C.Writer, getOptions *C.char) C.Result {
	s, ok := safes[C.GoString(safeName)]
	if !ok {
		return cResult(nil, ErrSafeNotFound)
	}

	var options safe.GetOptions
	err := cUnmarshal(getOptions, &options)
	if core.IsErr(err, nil, "cannot unmarshal getOptions: %v") {
		return cResult(nil, err)
	}

	header, err := safe.Get(s, C.GoString(name), CWriter{w}, options)
	if core.IsErr(err, nil, "cannot get file: %v") {
		return cResult(nil, err)
	}

	return cResult(header, nil)
}

//export getCString
func getCString(safeName, name, getOptions *C.char) C.Result {
	s, ok := safes[C.GoString(safeName)]
	if !ok {
		return cResult(nil, ErrSafeNotFound)
	}

	var options safe.GetOptions
	err := cUnmarshal(getOptions, &options)
	if core.IsErr(err, nil, "cannot unmarshal getOptions: %v") {
		return cResult(nil, err)
	}

	buf := bytes.Buffer{}
	_, err = safe.Get(s, C.GoString(name), &buf, options)
	if core.IsErr(err, nil, "cannot get file: %v") {
		return cResult(nil, err)
	}

	r := base64.StdEncoding.EncodeToString(buf.Bytes())
	return cResult(r, nil)
}

//export getFile
func getFile(safeName, name, destFile, getOptions *C.char) C.Result {
	s := safes[C.GoString(safeName)]
	if s == nil {
		return cResult(nil, ErrSafeNotFound)
	}

	var options safe.GetOptions
	err := cUnmarshal(getOptions, &options)
	if core.IsErr(err, nil, "cannot unmarshal getOptions: %v") {
		return cResult(nil, err)
	}

	dest := C.GoString(destFile)
	os.MkdirAll(filepath.Dir(dest), 0755)

	w, err := os.Create(dest)
	if core.IsErr(err, nil, "cannot create file: %v") {
		return cResult(nil, err)
	}

	header, err := safe.Get(s, C.GoString(name), w, options)
	if core.IsErr(err, nil, "cannot get file: %v") {
		return cResult(nil, err)
	}
	return cResult(header, nil)
}

//export setUsers
func setUsers(safeName *C.char, users *C.char, setUsersOptions *C.char) C.Result {
	s, ok := safes[C.GoString(safeName)]
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

//export getUsers
func getUsers(safeName *C.char) C.Result {
	s, ok := safes[C.GoString(safeName)]
	if !ok {
		return cResult(nil, ErrSafeNotFound)
	}

	users, err := safe.GetUsers(s)
	if core.IsErr(err, nil, "cannot get users: %v") {
		return cResult(nil, err)
	}
	return cResult(users, nil)
}

//export getIdentities
func getIdentities(safeName *C.char) C.Result {
	s, ok := safes[C.GoString(safeName)]
	if !ok {
		return cResult(nil, ErrSafeNotFound)
	}

	identities, err := safe.GetIdentities(s)
	if err != nil {
		return cResult(nil, err)
	}
	return cResult(identities, nil)
}

//export getLogs
func getLogs() C.Result {
	return cResult(core.RecentLog, nil)
}

//export setLogLevel
func setLogLevel(level C.int) C.Result {
	logrus.SetLevel(logrus.Level(level))
	core.Info("log level set to %d", level)
	return cResult(nil, nil)
}
