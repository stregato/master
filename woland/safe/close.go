package safe

func Close(s *Safe) {
	s.uploads.Stop()
	s.syncUsers.Stop()
	close(s.quit)
	close(s.upload)

	s.wg.Wait()
	for _, store := range s.stores {
		store.Close()
	}
}
