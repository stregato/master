#include "cfunc.h"

int callRead(Reader* r, void* data, int size) {
	return r->read(r->fd, data, size);
}

int callSeek(Reader *r, int offset, int whence) {
	return r->seek(r->fd, offset, whence);
}

int callWrite(Writer *w, void* data, int size) {
	return w->write(w->fd, data, size);
}
