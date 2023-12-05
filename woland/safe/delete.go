package safe

import (
	"github.com/stregato/master/woland/core"
	"github.com/stregato/master/woland/sql"
)

func DeleteFile(s *Safe, bucket string, fileId uint64) error {
	r, err := sql.Exec("SET_DELETED_FILE", sql.Args{
		"safe":   s.Name,
		"fileId": fileId,
	})
	if core.IsErr(err, nil, "cannot set deleted file for %d: %v", err) {
		return err
	}
	n, _ := r.RowsAffected()
	if n > 0 {
		core.Info("Marked [%d] as deleted in %s", fileId, s.Name)
	} else {
		core.Info("Cannot mark [%d] as deleted in %s because it does not exist", fileId, s.Name)
	}
	return nil
}
