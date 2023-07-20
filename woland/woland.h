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

typedef struct Result{
    char* res;
	char* err;
} Result;

typedef struct App {
	void (*feed)(char* name, char* data, int eof);
} App;

typedef int (*ReadCallbackFn)(char* data, int size);
typedef int (*SeekCallbackFn)(int offset, int whence);

typedef struct Reader	{
	ReadCallbackFn read;
	SeekCallbackFn seek;
} Reader;

int processRead(Reader reader, char* data, int size) {
	return reader.read(data, size);
}


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

extern Result start(char* dbPath, char* cachePath, char* availableBandwith);
extern Result stop();
extern Result factoryReset();
extern Result getConfig(char* node, char* key);
extern Result setConfig(char* node, char* key, char* s, int i, char* b);
extern Result newIdentity(char* nick);
extern Result setIdentity(char* identity);
extern Result getIdentity(char* id);
extern Result safeOpen(char* id, char* token, char* openOptions);
extern Result safeClose(char* safeName);
extern Result safeList(char* safeName, char* zoneName);
extern Result safePut(char* safeName, char* zoneName, char* name, Reader reader, char* putOptions);
extern Result safePutBytes(char* safeName, char* zoneName, char* name, void* data, size_t dataSize, char* putOptions);

#ifdef __cplusplus
}
#endif
