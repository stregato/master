package safe

func (s *Safe) Close() {
	s.store.Close()
}
