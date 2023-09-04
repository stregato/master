package core

import (
	"testing"
	"time"
)

func TestHash(t *testing.T) {
	input := uint64(1234567890)
	expected := hash16(input)

	if got := hash16(input); got != expected {
		t.Errorf("hash(%v) = %v; want %v", input, got, expected)
	}
}

func TestNextId(t *testing.T) {
	input := uint64(1234567890)
	id1 := NextID(input)
	id2 := NextID(input)

	if id1 == id2 {
		t.Errorf("IDs are not unique: %v == %v", id1, id2)
	}

	if id1>>63 != 1 {
		t.Errorf("Reserved bit is not set in ID: %v", id1)
	}

	if id2>>63 != 1 {
		t.Errorf("Reserved bit is not set in ID: %v", id2)
	}
}

func TestMatchOrigId(t *testing.T) {
	input := uint64(1234567890)
	id := NextID(input)

	if !MatchOrigId(id, input) {
		t.Errorf("MatchHash did not find matching hash for %v in ID %v", input, id)
	}
}

func TestTimeFromID(t *testing.T) {
	input := uint64(1234567890)
	id := NextID(input)
	expected := time.Now()

	// The resolution of our timestamp is 1ms, so let's truncate both times to ms
	expected = expected.Truncate(time.Millisecond)
	got := TimeFromID(id).Truncate(time.Millisecond)

	if got != expected {
		t.Errorf("TimeFromID(%v) = %v; want %v", id, got, expected)
	}
}
