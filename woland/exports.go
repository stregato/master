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
	"unsafe"

	"github.com/sirupsen/logrus"

	"github.com/stregato/master/massolit/core"
	"github.com/stregato/master/massolit/safe"
	"github.com/stregato/master/massolit/security"
	"github.com/stregato/master/massolit/sql"
)

var ErrPortalNotFound = fmt.Errorf("portal not found")
var portals = map[string]*safe.Pot{}

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

//export encodeToken
func encodeToken(userId *C.char, portalName *C.char, aesKey *C.char, urls *C.char) C.Result {
	var urls_ []string
	err := cUnmarshal(urls, &urls_)
	if core.IsErr(err, nil, "cannot unmarshal urls: %v") {
		return cResult(nil, err)
	}
	token, err := safe.EncodeToken(C.GoString(userId), C.GoString(portalName), []byte(C.GoString(aesKey)), urls_...)
	if core.IsErr(err, nil, "cannot create token: %v") {
		return cResult(nil, err)
	}
	return cResult(token, nil)
}

type decodedToken struct {
	PortalName string   `json:"portalName"`
	CreatorId  string   `json:"creatorId"`
	AesKey     []byte   `json:"aesKey"`
	Urls       []string `json:"urls"`
}

//export decodeAccess
func decodeAccess(identity *C.char, token *C.char) C.Result {
	var i security.Identity
	err := cUnmarshal(identity, &i)
	if core.IsErr(err, nil, "cannot unmarshal identity: %v") {
		return cResult(nil, err)
	}

	portalName, creatorId, aesKey, urls, err := safe.DecodeAccess(i, C.GoString(token))
	if core.IsErr(err, nil, "cannot transfer token: %v") {
		return cResult(nil, err)
	}
	return cResult(decodedToken{
		PortalName: portalName,
		CreatorId: ,
		AesKey:     aesKey,
		Urls:       urls,
	}, nil)
}

//export openPortal
func openPortal(identity *C.char, token *C.char, openOptions *C.char) C.Result {
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

	portal, err := safe.Open(i, C.GoString(token), OpenOptions)
	if core.IsErr(err, nil, "cannot open portal: %v") {
		return cResult(nil, err)
	}
	portals[safe.Name] = portal
	return cResult(portal, err)
}

//export closePortal
func closePortal(portalName *C.char) C.Result {
	s, ok := portals[C.GoString(portalName)]
	if !ok {
		return cResult(nil, ErrPortalNotFound)
	}
	s.Close()
	delete(portals, C.GoString(portalName))
	return cResult(nil, nil)
}

//export getIdentities
func getIdentities(portalName *C.char) C.Result {
	s, ok := portals[C.GoString(portalName)]
	if !ok {
		return cResult(nil, ErrPortalNotFound)
	}
	identities, err := s.GetIdentities()
	if err != nil {
		return cResult(nil, err)
	}
	return cResult(identities, nil)
}

//export listFiles
func listFiles(portalName, zoneName, listOptions *C.char) C.Result {
	s, ok := portals[C.GoString(portalName)]
	if !ok {
		return cResult(nil, ErrPortalNotFound)
	}
	var options safe.ListOptions
	err := cUnmarshal(listOptions, &options)
	if core.IsErr(err, nil, "cannot unmarshal listOptions %s: %v", C.GoString(listOptions)) {
		return cResult(nil, err)
	}

	headers, err := s.ListFiles(C.GoString(zoneName), options)
	return cResult(headers, err)
}

//export listSubFolders
func listSubFolders(portalName, zoneName, folder *C.char) C.Result {
	s, ok := portals[C.GoString(portalName)]
	if !ok {
		return cResult(nil, ErrPortalNotFound)
	}

	subFolders, err := s.ListSubFolders(C.GoString(zoneName), C.GoString(folder))
	return cResult(subFolders, err)
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
func putData(portalName, zoneName, name *C.char, r *C.Reader, putOptions *C.char) C.Result {
	s, ok := portals[C.GoString(portalName)]
	if !ok {
		return cResult(nil, ErrPortalNotFound)
	}

	var options safe.PutOptions
	err := cUnmarshal(putOptions, &options)
	if core.IsErr(err, nil, "cannot unmarshal putOptions: %v") {
		return cResult(nil, err)
	}

	header, err := s.Put(C.GoString(zoneName), C.GoString(name), CReader{r}, options)
	if core.IsErr(err, nil, "cannot put file: %v") {
		return cResult(nil, err)
	}

	return cResult(header, nil)
}

//export putCString
func putCString(portalName, zoneName, name, data *C.char,
	putOptions *C.char) C.Result {

	s, ok := portals[C.GoString(portalName)]
	if !ok {
		return cResult(nil, ErrPortalNotFound)
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

	header, err := s.Put(C.GoString(zoneName), C.GoString(name), r, options)
	if core.IsErr(err, nil, "cannot put file: %v") {
		return cResult(nil, err)
	}
	return cResult(header, nil)
}

//export putFile
func putFile(portalName, zoneName, name *C.char, sourceFile *C.char, putOptions *C.char) C.Result {
	s, ok := portals[C.GoString(portalName)]
	if !ok {
		return cResult(nil, ErrPortalNotFound)
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

	header, err := s.Put(C.GoString(zoneName), C.GoString(name), r, options)
	if core.IsErr(err, nil, "cannot put file: %v") {
		return cResult(nil, err)
	}
	return cResult(header, nil)
}

//export getData
func getData(portalName, zoneName, name *C.char, w *C.Writer, getOptions *C.char) C.Result {
	s, ok := portals[C.GoString(portalName)]
	if !ok {
		return cResult(nil, ErrPortalNotFound)
	}

	var options safe.GetOptions
	err := cUnmarshal(getOptions, &options)
	if core.IsErr(err, nil, "cannot unmarshal getOptions: %v") {
		return cResult(nil, err)
	}

	header, err := s.Get(C.GoString(zoneName), C.GoString(name), CWriter{w}, options)
	if core.IsErr(err, nil, "cannot get file: %v") {
		return cResult(nil, err)
	}

	return cResult(header, nil)
}

//export getCString
func getCString(portalName, zoneName, name, getOptions *C.char) C.Result {
	s, ok := portals[C.GoString(portalName)]
	if !ok {
		return cResult(nil, ErrPortalNotFound)
	}

	var options safe.GetOptions
	err := cUnmarshal(getOptions, &options)
	if core.IsErr(err, nil, "cannot unmarshal getOptions: %v") {
		return cResult(nil, err)
	}

	buf := bytes.Buffer{}
	_, err = s.Get(C.GoString(zoneName), C.GoString(name), &buf, options)
	if core.IsErr(err, nil, "cannot get file: %v") {
		return cResult(nil, err)
	}

	r := base64.StdEncoding.EncodeToString(buf.Bytes())
	return cResult(r, nil)
}

//export getFile
func getFile(portalName, zoneName, name, destFile, getOptions *C.char) C.Result {
	s := portals[C.GoString(portalName)]
	if s == nil {
		return cResult(nil, ErrPortalNotFound)
	}

	var options safe.GetOptions
	err := cUnmarshal(getOptions, &options)
	if core.IsErr(err, nil, "cannot unmarshal getOptions: %v") {
		return cResult(nil, err)
	}

	w, err := os.Create(C.GoString(destFile))
	if core.IsErr(err, nil, "cannot create file: %v") {
		return cResult(nil, err)
	}

	header, err := s.Get(C.GoString(zoneName), C.GoString(name), w, options)
	if core.IsErr(err, nil, "cannot get file: %v") {
		return cResult(nil, err)
	}
	return cResult(header, nil)
}

//export createZone
func createZone(portalName, zoneName *C.char, users *C.char) C.Result {
	s, ok := portals[C.GoString(portalName)]
	if !ok {
		return cResult(nil, ErrPortalNotFound)
	}

	var users_ safe.Users
	err := cUnmarshal(users, &users_)
	if core.IsErr(err, nil, "cannot unmarshal users: %v") {
		return cResult(nil, err)
	}

	err = s.CreateZone(C.GoString(zoneName), users_)
	if core.IsErr(err, nil, "cannot create zone: %v") {
		return cResult(nil, err)
	}

	return cResult(nil, nil)
}

//export listZones
func listZones(portalName *C.char) C.Result {
	s, ok := portals[C.GoString(portalName)]
	if !ok {
		return cResult(nil, ErrPortalNotFound)
	}

	zones, err := s.ListZones()
	if core.IsErr(err, nil, "cannot get zones: %v") {
		return cResult(nil, err)
	}
	return cResult(zones, nil)
}

//export setUsers
func setUsers(portalName, zoneName *C.char, users *C.char) C.Result {
	s, ok := portals[C.GoString(portalName)]
	if !ok {
		return cResult(nil, ErrPortalNotFound)
	}

	var users_ safe.Users
	err := cUnmarshal(users, &users_)
	if core.IsErr(err, nil, "cannot unmarshal users: %v") {
		return cResult(nil, err)
	}

	err = s.SetUsers(C.GoString(zoneName), users_)
	if core.IsErr(err, nil, "cannot set users: %v") {
		return cResult(nil, err)
	}
	return cResult(nil, nil)
}

//export getUsers
func getUsers(portalName, zoneName *C.char) C.Result {
	s, ok := portals[C.GoString(portalName)]
	if !ok {
		return cResult(nil, ErrPortalNotFound)
	}

	users, err := s.GetUsers(C.GoString(zoneName))
	if core.IsErr(err, nil, "cannot get users: %v") {
		return cResult(nil, err)
	}
	return cResult(users, nil)
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
