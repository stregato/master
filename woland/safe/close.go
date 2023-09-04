package safe

func Close(s *Safe) {
	for _, store := range s.stores {
		store.Close()
	}
}
