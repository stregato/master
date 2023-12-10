package safe

import "github.com/stregato/master/woland/core"

func backgroundJob(s *Safe) {
	s.wg.Add(1)
	for {
		select {
		case _, ok := <-s.background.C:
			if !ok { // channel closed
				continue
			}
		case _, ok := <-s.uploadFile:
			if !ok { // channel closed
				continue
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

		SyncUsers(s)
		uploadFilesInBackground(s)
	}
}