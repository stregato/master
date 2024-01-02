package safe

import (
	"github.com/godruoyi/go-snowflake"

	"github.com/stregato/master/woland/core"
)

type PatchOptions struct {
	ByName bool `json:"byName"` // Patch by name instead of fileId. Hash and size will be ignored in the patch
	Async  bool `json:"async"`  // Patch asynchronously
}

func Patch(s *Safe, bucket string, header Header, options PatchOptions) (Header, error) {
	var err error

	if options.ByName {
		head, _, err := getLastHeader(s.Name, bucket, header.Name, 0)
		if core.IsErr(err, nil, "cannot get last header: %v", err) {
			return Header{}, err
		}
		header.FileId = head.FileId
		header.Attributes.Hash = head.Attributes.Hash
		header.Size = head.Size
	}

	headerId := snowflake.ID()
	err = insertHeaderOrIgnoreToDB(s.Name, bucket, headerId, header)
	if core.IsErr(err, nil, "cannot insert header: %v", err) {
		return Header{}, err
	}
	core.Info("Inserted header for %s[%d]", header.Name, header.FileId)

	if options.Async {
		go writeHeader(s, bucket, header, headerId)
		return header, nil
	}

	return writeHeader(s, bucket, header, headerId)
}
