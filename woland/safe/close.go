package safe

func Close(s *Safe) {
	s.background.Stop()
	close(s.quit)
	close(s.uploadFile)
	close(s.syncUsers)
	close(s.compactHeaders)

	s.wg.Wait()
	if s.PrimaryStore != nil {
		s.PrimaryStore.Close()
	}
	if s.SecondaryStore != nil {
		s.SecondaryStore.Close()
	}
}
