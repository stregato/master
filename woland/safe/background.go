package safe

import (
	"time"

	"github.com/stregato/master/woland/core"
)

func backgroundJob(s *Safe) {
	s.wg.Add(1)
	for {
		select {
		case _, ok := <-s.background.C:
			if ok { // channel closed
				SyncUsers(s)
				uploadFilesInBackground(s)
				if core.Since(s.lastQuotaEnforcement) > 15*time.Minute {
					enforceQuota(s)
					s.lastQuotaEnforcement = core.Now()
				}
			}
		case task, ok := <-s.uploadFile:
			if ok { // channel closed
				uploadFileInBackground(s, task)
			}
			continue
		case _, ok := <-s.enforceQuota:
			if ok { // channel closed
				enforceQuota(s)
			}
		case c, ok := <-s.compactHeaders:
			if ok {
				compactHeadersInBucket(s, c.BucketDir, c.NewKey)
			}
			continue
		case <-s.quit:
			core.Info("Upload job for %s stopped", s.Name)
			s.wg.Done()
			return
		}
	}
}
