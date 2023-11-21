package safe

func Close(s *Safe) {
	s.syncUsers.Stop()
	for _, store := range s.stores {
		store.Close()
	}
}
