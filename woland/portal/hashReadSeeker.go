package portal

import (
	"hash"
	"io"
)

type hashingReadSeeker struct {
	rs        io.ReadSeeker
	hash      hash.Hash
	bytesRead int64
	progress  chan int64
}

func hashSizeReader(rs io.ReadSeeker, hash hash.Hash, progress chan int64) *hashingReadSeeker {
	return &hashingReadSeeker{
		rs:       rs,
		hash:     hash,
		progress: progress,
	}
}

func (hrs *hashingReadSeeker) Read(p []byte) (n int, err error) {
	n, err = hrs.rs.Read(p)
	hrs.hash.Write(p[:n])
	hrs.bytesRead += int64(n)
	if hrs.progress != nil {
		hrs.progress <- int64(n)
	}
	return n, err
}

func (hrs *hashingReadSeeker) Seek(offset int64, whence int) (int64, error) {
	if whence == io.SeekStart {
		_, err := hrs.rs.Seek(0, io.SeekStart)
		if err != nil {
			return 0, err
		}
		hrs.hash.Reset()
		hrs.bytesRead = 0
	}

	return hrs.rs.Seek(offset, whence)
}

type progressWriter_ struct {
	w        io.Writer
	progress chan<- int64
}

func progressWriter(w io.Writer, progress chan int64) *progressWriter_ {
	return &progressWriter_{
		w:        w,
		progress: progress,
	}
}

func (pw *progressWriter_) Write(p []byte) (n int, err error) {
	n, err = pw.w.Write(p)
	if n > 0 {
		if pw.progress != nil {
			pw.progress <- int64(n)
		}
	}
	return n, err
}
