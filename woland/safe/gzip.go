package safe

import (
	"bytes"
	"compress/gzip"
	"fmt"
	"io"

	"github.com/stregato/master/woland/core"
)

func gzipStream(input io.ReadSeeker) (io.ReadSeeker, error) {
	// Create an in-memory buffer to store the compressed data
	var compressedData bytes.Buffer

	// Create a gzip writer that writes to the buffer
	gzipWriter := gzip.NewWriter(&compressedData)

	// Copy the input data to the gzip writer
	_, err := io.Copy(gzipWriter, input)
	if core.IsErr(err, nil, "failed to compress data: %v", err) {
		return nil, err
	}
	// Close the gzip writer to flush any remaining compressed data
	err = gzipWriter.Close()
	if err != nil {
		return nil, fmt.Errorf("failed to close gzip writer: %v", err)
	}

	return core.NewBytesReader(compressedData.Bytes()), nil
}

// func gunzipStream(input io.Writer) (io.Writer, error) {
// 	// Create a pipe to connect the input and output writers
// 	reader, writer := io.Pipe()

// 	// Goroutine to copy the decompressed data to the input writer
// 	go func() {
// 		// Create a gzip reader from the reader end of the pipe
// 		gzipReader, err := gzip.NewReader(reader)
// 		if err != nil {
// 			_ = writer.CloseWithError(err) // Signal to the writer that an error occurred
// 			_ = reader.CloseWithError(err)
// 			return
// 		}
// 		// Copy the decompressed data to the input writer
// 		if _, err := io.Copy(input, gzipReader); err != nil {
// 			_ = reader.CloseWithError(err) // Handle the error and signal to the writer
// 		}

// 		// Closing the reader will also close the writer, signaling to the writer end
// 		_ = reader.Close()

// 		_, _ = io.Copy(input, gzipReader)
// 		_ = gzipReader.Close()
// 		_ = writer.Close()
// 	}()

// 	return writer, nil
// }
