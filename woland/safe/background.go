package safe

import (
	"time"

	"github.com/stregato/master/woland/core"
)

func backgroundJob(s *Safe) {
	s.wg.Add(1)
	for {
		select {
		case _, ok := <-s.connect:
			if ok {
				connect(s)
			}
		case task, ok := <-s.uploadFile:
			if ok { // channel closed
				uploadFileInBackground(s, task)
			}
		case _, ok := <-s.enforceQuota:
			if ok { // channel closed
				enforceQuota(s)
			}
		case c, ok := <-s.compactHeaders:
			if ok {
				compactHeadersInBucket(s, c.BucketDir, c.NewKey)
			}
		case <-s.quit:
			core.Info("Upload job for %s stopped", s.Name)
			s.wg.Done()
			return
		case _, ok := <-s.background.C:
			if ok { // channel closed
				if !s.Connected {
					connect(s)
				} else {
					SyncUsers(s)
					uploadFilesInBackground(s)
					if core.Since(s.lastQuotaEnforcement) > 15*time.Minute {
						enforceQuota(s)
						s.lastQuotaEnforcement = core.Now()
					}
				}

			}
		}
	}
}
