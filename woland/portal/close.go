package portal

func (s *Portal) Close() {
	s.store.Close()
}
