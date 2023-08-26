package safe

import (
	"bytes"
	"errors"
	"image"
	"image/gif"
	"image/jpeg"
	"image/png"

	"github.com/nfnt/resize"
	"golang.org/x/image/bmp"
	"golang.org/x/image/tiff"
)

const targetSize = 64 * 1024 // 64KB

func GenerateThumbnail(input []byte) ([]byte, error) {
	// Detect image format
	_, format, err := image.DecodeConfig(bytes.NewReader(input))
	if err != nil {
		return nil, err
	}

	// Decode the image
	img, _, err := image.Decode(bytes.NewReader(input))
	if err != nil {
		return nil, err
	}

	// Downsize the image
	smallImg := resize.Thumbnail(200, 200, img, resize.Lanczos3)

	// Decrease quality until target size is met
	for quality := 100; quality >= 1; quality -= 5 {
		var buf bytes.Buffer
		switch format {
		case "jpeg":
			err = jpeg.Encode(&buf, smallImg, &jpeg.Options{Quality: quality})
		case "png":
			err = png.Encode(&buf, smallImg)
		case "gif":
			err = gif.Encode(&buf, smallImg, nil)
		case "bmp":
			err = bmp.Encode(&buf, smallImg)
		case "tiff":
			err = tiff.Encode(&buf, smallImg, nil)
		default:
			return nil, errors.New("unsupported format")
		}
		if err != nil {
			return nil, err
		}
		if buf.Len() <= targetSize {
			return buf.Bytes(), nil
		}
	}

	return nil, errors.New("unable to fit image within target size")
}
