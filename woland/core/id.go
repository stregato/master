package core

import (
	"crypto/sha1"
	"encoding/binary"
	"sync"
	"sync/atomic"
	"time"
)

const (
	ReservedBit  uint64 = 1 << 63
	MaxTimestamp uint64 = 1<<41 - 1
	MaxHash      uint64 = 1<<16 - 1
	MaxSequence  uint64 = 1<<6 - 1
)

var (
	sequence uint64
	seqMutex sync.Mutex
)

// hash16 generates a 16-bit hash16 from a 64-bit integer
func hash16(n uint64) uint64 {
	data := make([]byte, 8)
	binary.BigEndian.PutUint64(data, n)
	hash := sha1.Sum(data)

	// We only need the first 16 bits, so we take the first 2 bytes
	// and convert them into a uint64
	return uint64(binary.BigEndian.Uint16(hash[:2]))
}

func NextID(n uint64) uint64 {
	seq := atomic.AddUint64(&sequence, 1) - 1

	// If sequence reaches its max, we need to reset it
	if seq >= MaxSequence {
		seqMutex.Lock()
		// Double-checking here to prevent a race condition
		if sequence >= MaxSequence {
			sequence = 0
		}
		seqMutex.Unlock()
		seq = atomic.AddUint64(&sequence, 1) - 1
	}

	// Get current timestamp in milliseconds
	now := uint64(time.Now().UnixNano() / 1e6)

	// Ensure timestamp is within limit
	now &= MaxTimestamp

	// Hash the input number and ensure it's within limit
	h := hash16(n)
	h &= MaxHash

	// Create the ID
	id := (now << 22) | (h << 6) | seq

	return id
}
func MatchOrigId(id uint64, orig uint64) bool {
	h := hash16(orig)
	return (id>>6)&MaxHash == h
}

func TimeFromID(id uint64) time.Time {
	// Retrieve the timestamp part from the identifier by right-shifting and applying a mask
	timestamp := (id >> 22) & MaxTimestamp

	// Convert to a time.Time, note that the timestamp is in milliseconds
	return time.Unix(0, int64(timestamp)*int64(time.Millisecond))
}
