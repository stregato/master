#ifndef _CFUNC_H
#define _CFUNC_H

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


typedef struct Writer {
	void* fd;
	int (*write)(void* fd, void* data, int size);
} Writer;

extern int callRead(Reader* r, void* data, int size);
extern int callSeek(Reader *r, int offset, int whence);
extern int callWrite(Writer *w, void* data, int size);

typedef void(*Callback)(Result result);
extern void callCallback(Callback f, Result result);

#endif