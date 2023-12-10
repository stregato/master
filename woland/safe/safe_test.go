package safe

import "testing"

func TestAll(t *testing.T) {
	InitTest()
	TestCreateAndOpen(t)
	TestList(t)
	TestPut(t)
	TestAddSecondUser(t)
}
