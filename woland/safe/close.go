package safe

func Close(s *Safe) {
	s.background.Stop()
	close(s.quit)
	close(s.uploadFile)
	close(s.syncUsers)
	close(s.compactHeaders)

	s.wg.Wait()
	s.store.Close()
}
