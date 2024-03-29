/* Code generated by cmd/cgo; DO NOT EDIT. */

/* package github.com/stregato/master/woland */


#line 1 "cgo-builtin-export-prolog"

#include <stddef.h>

#ifndef GO_CGO_EXPORT_PROLOGUE_H
#define GO_CGO_EXPORT_PROLOGUE_H

#ifndef GO_CGO_GOSTRING_TYPEDEF
typedef struct { const char *p; ptrdiff_t n; } _GoString_;
#endif

#endif

/* Start of preamble from import "C" comments.  */


#line 3 "exports.go"

#include "cfunc.h"
#include <stdlib.h>

#line 1 "cgo-generated-wrapper"


/* End of preamble from import "C" comments.  */


/* Start of boilerplate cgo prologue.  */
#line 1 "cgo-gcc-export-header-prolog"

#ifndef GO_CGO_PROLOGUE_H
#define GO_CGO_PROLOGUE_H

typedef signed char GoInt8;
typedef unsigned char GoUint8;
typedef short GoInt16;
typedef unsigned short GoUint16;
typedef int GoInt32;
typedef unsigned int GoUint32;
typedef long long GoInt64;
typedef unsigned long long GoUint64;
typedef GoInt64 GoInt;
typedef GoUint64 GoUint;
typedef size_t GoUintptr;
typedef float GoFloat32;
typedef double GoFloat64;
#ifdef _MSC_VER
#include <complex.h>
typedef _Fcomplex GoComplex64;
typedef _Dcomplex GoComplex128;
#else
typedef float _Complex GoComplex64;
typedef double _Complex GoComplex128;
#endif

/*
  static assertion to make sure the file is being used on architecture
  at least with matching size of GoInt.
*/
typedef char _check_for_64_bit_pointer_matching_GoInt[sizeof(void*)==64/8 ? 1:-1];

#ifndef GO_CGO_GOSTRING_TYPEDEF
typedef _GoString_ GoString;
#endif
typedef void *GoMap;
typedef void *GoChan;
typedef struct { void *t; void *v; } GoInterface;
typedef struct { void *data; GoInt len; GoInt cap; } GoSlice;

#endif

/* End of boilerplate cgo prologue.  */

#ifdef __cplusplus
extern "C" {
#endif

extern Result wlnd_start(char* dbPath, char* appPath);
extern Result wlnd_stop();
extern Result wlnd_factoryReset();
extern Result wlnd_getConfig(char* node, char* key);
extern Result wlnd_setConfig(char* node, char* key, char* value);
extern Result wlnd_newIdentity(char* nick);
extern Result wlnd_newIdentityFromId(char* nick, char* privateId);
extern Result wlnd_setIdentity(char* identity);
extern Result wlnd_getIdentity(char* id);
extern Result wlnd_createSafe(char* creator, char* name, char* storeConfig, char* users, char* createOptions);
extern Result wlnd_addStore(int hnd, char* storeConfig);
extern Result wlnd_openSafe(char* identity, char* name, char* storeUrl, char* creatorId, char* openOptions);
extern Result wlnd_closeSafe(int hnd);
extern Result wlnd_syncBucket(int hnd, char* bucket, char* syncOptions);
extern Result wlnd_syncUsers(int hnd);
extern Result wlnd_listFiles(int hnd, char* dir, char* listOptions);
extern Result wlnd_listDirs(int hnd, char* bucket, char* listDirsOptions);
extern Result wlnd_putData(int hnd, char* bucket, char* name, Reader* r, char* putOptions);
extern Result wlnd_putCString(int hnd, char* bucket, char* name, char* data, char* putOptions);
extern Result wlnd_putFile(int hnd, char* bucket, char* name, char* sourceFile, char* putOptions);
extern Result wlnd_patch(int hnd, char* bucket, char* header, char* patchOptions);
extern Result wlnd_getData(int hnd, char* bucket, char* name, Writer* w, char* getOptions);
extern Result wlnd_getCString(int hnd, char* bucket, char* name, char* getOptions);
extern Result wlnd_getFile(int hnd, char* bucket, char* name, char* destFile, char* getOptions);
extern Result wlnd_deleteFile(int hnd, char* bucket, long fileId);
extern Result wlnd_setUsers(int hnd, char* users, char* setUsersOptions);
extern Result wlnd_getUsers(int hnd);
extern Result wlnd_getInitiates(int hnd);
extern Result wlnd_getAllIdentities();
extern Result wlnd_getLogs();
extern Result wlnd_setLogLevel(int level);

#ifdef __cplusplus
}
#endif
