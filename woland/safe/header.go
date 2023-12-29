package safe

import (
	"bytes"
	"crypto/aes"
	"crypto/cipher"
	"crypto/rand"
	"encoding/binary"
	"encoding/json"
	"fmt"
	"io"
	"path"
	"sort"
	"strings"
	"sync"
	"time"

	"github.com/godruoyi/go-snowflake"
	"github.com/stregato/master/woland/core"
	"github.com/stregato/master/woland/security"
	"github.com/stregato/master/woland/sql"
	"github.com/stregato/master/woland/storage"
)

var MaxHeadersFiles = 16
var MaxHeaderFileSize = 1024 * 1024 * 4 // 4MB
var MergeBatchSize = 4

var ErrInvalidHeaders = fmt.Errorf("headers are invalid")
var ErrNoEncryptionKey = fmt.Errorf("no encryption key")

type Attributes struct {
	Hash        []byte         `json:"ha,omitempty"` // Hash of the file
	ContentType string         `json:"co,omitempty"` // Content type of the file
	Thumbnail   []byte         `json:"th,omitempty"` // Thumbnail of the file
	Tags        []string       `json:"ta,omitempty"` // Tags of the file
	Meta        map[string]any `json:"mt,omitempty"` // Extra attributes of the file
}

type Header struct {
	Name                string               `json:"na"`            // Full path of the file
	Creator             string               `json:"cr"`            // Creator of the file
	Size                int64                `json:"si"`            //	Size of the file
	ModTime             time.Time            `json:"mo"`            // Last modification time of the file
	FileId              uint64               `json:"fi"`            // ID used in the storage to identify the file
	IV                  []byte               `json:"iv"`            // IV used to encrypt the attributes
	Zip                 bool                 `json:"zi,omitempty"`  // True if the file is zipped
	Attributes          Attributes           `json:"at,omitempty"`  // Attributes of the file
	EncryptedAttributes []byte               `json:"en,omitempty"`  // Encrypted attributes of the file
	BodyKey             []byte               `json:"bo,omitempty"`  // Key used to encrypt the body
	PrivateId           string               `json:"pr,omitempty"`  // ID of the user in case of private encryption
	Deleted             bool                 `json:"de,omitempty"`  // True if the file is deleted
	Cached              string               `json:"ca,omitempty"`  // Location where the file is cached
	CachedExpires       time.Time            `json:"cac,omitempty"` // Time when the cache expires
	Uploading           bool                 `json:"up,omitempty"`  // Number of uploads retries
	SourceFile          string               `json:"so,omitempty"`  // Source of the file
	ReplaceId           uint64               `json:"re,omitempty"`  // ID of the file to replace
	Replace             bool                 `json:"rp,omitempty"`  // True if the file is replacing another file
	Downloads           map[string]time.Time `json:"do,omitempty"`  // Map of download locations and times
}

type HeadersFile struct {
	KeyId   uint64   `json:"-"`
	Bucket  string   `json:"b"`
	Headers []Header `json:"h"`
}

func marshalHeadersFile(headersFile HeadersFile, keyValue []byte) ([]byte, error) {
	data, err := json.Marshal(headersFile)
	if core.IsErr(err, nil, "cannot marshal files: %v", err) {
		return nil, err
	}

	block, err := aes.NewCipher(keyValue)
	if core.IsErr(err, nil, "cannot create cipher: %v", err) {
		return nil, err
	}

	ciphertext := make([]byte, 8+aes.BlockSize+len(data)) // 8 bytes for the KeyID
	binary.BigEndian.PutUint64(ciphertext[:8], headersFile.KeyId)

	iv := ciphertext[8 : 8+aes.BlockSize]
	if _, err := io.ReadFull(rand.Reader, iv); err != nil {
		if core.IsErr(err, nil, "cannot read random bytes: %v", err) {
			return nil, err
		}
	}

	stream := cipher.NewCFBEncrypter(block, iv)
	stream.XORKeyStream(ciphertext[8+aes.BlockSize:], data)

	return ciphertext, nil
}

func unmarshalHeadersFile(ciphertext []byte, keys map[uint64][]byte) (headersFile HeadersFile, err error) {
	if len(ciphertext) < 8 {
		return HeadersFile{}, ErrInvalidHeaders
	}

	keyId := binary.BigEndian.Uint64(ciphertext[:8])

	key := keys[keyId]
	if key == nil {
		return HeadersFile{}, ErrNoEncryptionKey
	}

	block, err := aes.NewCipher(key)
	if err != nil {
		return HeadersFile{}, err
	}

	iv := ciphertext[8 : 8+aes.BlockSize]
	stream := cipher.NewCFBDecrypter(block, iv)
	stream.XORKeyStream(ciphertext[8+aes.BlockSize:], ciphertext[8+aes.BlockSize:])

	var headerFile HeadersFile
	err = json.Unmarshal(ciphertext[8+aes.BlockSize:], &headersFile)
	if err != nil {
		return headerFile, err
	}

	headerFile.KeyId = keyId
	return headersFile, nil
}

func writeHeadersFile(store storage.Store, safeName string, filePath string, key []byte, headersFile HeadersFile) error {
	data, err := marshalHeadersFile(headersFile, key)
	if core.IsErr(err, nil, "cannot encrypt header: %v", err) {
		return err
	}

	hr := core.NewBytesReader(data)
	err = store.Write(filePath, hr, nil)
	if core.IsErr(err, nil, "cannot write header: %v", err) {
		return err
	}
	core.Info("Wrote headers to %s/%s", store, filePath)
	return nil
}

func readHeadersFile(store storage.Store, safeName string, filePath string, keys Keys) (HeadersFile, error) {
	var buf bytes.Buffer
	err := store.Read(filePath, nil, &buf, nil)
	if core.IsErr(err, nil, "cannot read file %s/%s: %v", store, filePath, err) {
		return HeadersFile{}, err
	}

	headersFile, err := unmarshalHeadersFile(buf.Bytes(), keys)
	if err == ErrNoEncryptionKey || core.IsErr(err, nil, "cannot unmarshal headers: %v", err) {
		return HeadersFile{}, err
	}
	return headersFile, nil
}

func insertHeaderOrIgnoreToDB(safeName, bucket string, headerFile uint64, header Header) error {
	data, err := json.Marshal(header)
	if core.IsErr(err, nil, "cannot marshal header: %v", err) {
		return err
	}

	header.Name = path.Clean(header.Name)
	depth := strings.Count(header.Name, "/")
	tags := strings.Join(header.Attributes.Tags, " ") + " "
	r, err := sql.Exec("INSERT_HEADER", sql.Args{
		"safe":         safeName,
		"bucket":       bucket,
		"name":         header.Name,
		"size":         header.Size,
		"fileId":       header.FileId,
		"headerFile":   headerFile,
		"base":         path.Base(header.Name),
		"dir":          getDir(header.Name),
		"depth":        depth,
		"modTime":      header.ModTime.UnixMilli(),
		"syncTime":     core.Now().UnixMilli(),
		"tags":         tags,
		"contentType":  header.Attributes.ContentType,
		"creator":      header.Creator,
		"privateId":    header.PrivateId,
		"deleted":      header.Deleted,
		"cacheExpires": header.CachedExpires.UnixMilli(),
		"uploading":    header.Uploading,
		"header":       data,
	})
	if core.IsErr(err, nil, "cannot save header: %v", err) {
		return err
	}

	if count, _ := r.RowsAffected(); count == 0 {
		core.Info("Header %s already exists", header.Name)
		return nil
	}
	core.Info("Saved header %s [%d]", header.Name, header.FileId)

	return nil
}

func updateHeaderInDB(safeName, bucket string, fileId uint64, update func(Header) Header) error {
	var data []byte

	err := sql.QueryRow("GET_LAST_HEADER", sql.Args{
		"safe":   safeName,
		"bucket": bucket,
		"name":   "",
		"fileId": fileId}, &data)
	if core.IsErr(err, nil, "cannot get header: %v", err) {
		return err
	}

	var header Header
	err = json.Unmarshal(data, &header)
	if core.IsErr(err, nil, "cannot unmarshal header: %v", err) {
		return err
	}

	header = update(header)
	data, err = json.Marshal(header)
	if core.IsErr(err, nil, "cannot marshal header: %v", err) {
		return err
	}

	_, err = sql.Exec("UPDATE_HEADER", sql.Args{
		"safe":         safeName,
		"bucket":       bucket,
		"fileId":       fileId,
		"cacheExpires": header.CachedExpires.Unix(),
		"uploading":    header.Uploading,
		"header":       data})
	if core.IsErr(err, nil, "cannot update header: %v", err) {
		return err
	}
	return nil
}

func getDiffHillmanKey(currentUser security.Identity, header Header) ([]byte, error) {
	if header.PrivateId == currentUser.Id {
		secondaryKey, err := security.DiffieHellmanKey(currentUser, header.Creator)
		if core.IsErr(err, nil, "cannot create secondary key: %v", err) {
			return secondaryKey, err
		}
		return secondaryKey, nil
	} else if header.Creator == currentUser.Id {
		secondaryKey, err := security.DiffieHellmanKey(currentUser, header.PrivateId)
		if core.IsErr(err, nil, "cannot create secondary key: %v", err) {
			return secondaryKey, err
		}
		return secondaryKey, nil
	} else {
		return nil, ErrNoEncryptionKey
	}
}

func encryptHeaderAttributes(key []byte, iv []byte, attributes Attributes) ([]byte, error) {
	data, err := json.Marshal(attributes)
	if core.IsErr(err, nil, "cannot marshal attributes: %v", err) {
		return nil, err
	}
	encryptedAttributes, err := security.EncryptBlock(key, iv, data)
	if core.IsErr(err, nil, "cannot encrypt attributes: %v", err) {
		return nil, err
	}
	return encryptedAttributes, nil
}

func decryptHeaderAttributes(key []byte, iv []byte, encryptedAttributes []byte) (Attributes, error) {
	var attributes Attributes
	data, err := security.DecryptBlock(key, iv, encryptedAttributes)
	if core.IsErr(err, nil, "cannot decrypt attributes: %v", err) {
		return attributes, err
	}
	err = json.Unmarshal(data, &attributes)
	if core.IsErr(err, nil, "cannot unmarshal attributes: %v", err) {
		return attributes, err
	}
	return attributes, nil
}

func decryptPrivateHeader(currentUser security.Identity, header Header) (Header, error) {
	if header.PrivateId != "" && header.BodyKey == nil {
		key, err := getDiffHillmanKey(currentUser, header)
		if core.IsErr(err, nil, "cannot get hillman key: %v", err) {
			return header, err
		}
		attributes, err := decryptHeaderAttributes(key, header.IV, header.EncryptedAttributes)
		if core.IsErr(err, nil, "cannot decrypt attributes: %v", err) {
			return header, err
		}
		header.Attributes = attributes
		header.EncryptedAttributes = nil
		header.BodyKey = key
	}
	return header, nil
}

func getHeadersIdsWithCount(store storage.Store, safeName, bucket string) (ids map[uint64]int, err error) {
	rows, err := sql.Query("GET_HEADERS_IDS", sql.Args{
		"safe":   safeName,
		"bucket": bucket,
	})
	if err != sql.ErrNoRows && core.IsErr(err, nil, "cannot get headers ids: %v", err) {
		return nil, err
	}

	ids = map[uint64]int{}
	for rows.Next() {
		var id uint64
		var count int
		if core.IsErr(rows.Scan(&id, &count), nil, "cannot scan id: %v", err) {
			continue
		}
		ids[id] = count
	}
	rows.Close()
	return ids, nil
}

type CompactHeader struct {
	BucketDir string
	NewKey    bool
}

func compactHeaders(s *Safe, newKey bool) error {
	ls, err := s.primary.ReadDir(path.Join(s.Name, DataFolder), storage.Filter{})
	if core.IsErr(err, nil, "cannot read dir %s/%s: %v", s.primary, s.Name, err) {
		return err
	}

	for _, l := range ls {
		if l.IsDir() {
			s.compactHeadersWg.Add(1)
			s.compactHeaders <- CompactHeader{BucketDir: l.Name(), NewKey: true}
		}
	}

	if newKey {
		s.compactHeadersWg.Wait()
	}

	return nil
}

func compactHeadersInBucket(s *Safe, buckerDir string, newKey bool) {
	defer s.compactHeadersWg.Done()

	folder := path.Join(s.Name, DataFolder, buckerDir, HeaderFolder)
	store := s.primary
	ls, err := store.ReadDir(folder, storage.Filter{})
	if core.IsErr(err, nil, "cannot read dir %s/%s: %v", store, folder, err) {
		return
	}

	var files []string
	for _, l := range ls {
		if newKey || l.Size() < int64(MaxHeaderFileSize) {
			files = append(files, l.Name())
		}
	}
	if !newKey && len(files) < MaxHeadersFiles {
		return
	}

	stat, err := store.Stat(path.Join(folder, ".merging"))
	if err == nil && core.Since(stat.ModTime()) < time.Hour {
		return
	}

	err = store.Write(path.Join(folder, ".merging"), core.NewBytesReader(nil), nil)
	if core.IsErr(err, nil, "cannot write merging guard: %v", err) {
		return
	}

	sort.Strings(files)
	var wg sync.WaitGroup
	for i := 0; i < len(files); {
		fileSize := 0
		j := i
		for j-i < MergeBatchSize && fileSize < MaxHeaderFileSize && j < len(files) {
			fileSize += int(ls[j].Size())
			j++
		}

		wg.Add(1)
		go mergeHeadersFiles(s, folder, files[i:j], &wg)
		i = j + 1
	}

	wg.Wait()
	err = store.Delete(path.Join(folder, ".merging"))
	core.IsErr(err, nil, "cannot delete merging guard: %v", err)
}

func mergeHeadersFiles(s *Safe, folder string, files []string, wg *sync.WaitGroup) {
	headersMap := map[uint64]Header{}
	store := s.primary
	safeName := s.Name

	var bucket string
	var filesToDelete []string
	for _, file := range files {
		filepath := path.Join(folder, file)
		headerFile, err := readHeadersFile(store, safeName, filepath, s.keystore.Keys)
		if core.IsErr(err, nil, "cannot read headers: %v", err) {
			continue
		}
		bucket = headerFile.Bucket
		if bucket == "" {
			continue
		}
		for _, header := range headerFile.Headers {
			h, found := headersMap[header.FileId]
			if !found || h.ModTime.Before(header.ModTime) {
				headersMap[header.FileId] = header
			}
		}
		filesToDelete = append(filesToDelete, filepath)
		core.Info("Added header file %s/%s to the merge", store, filepath)
	}

	if bucket == "" {
		return
	}

	headerFileId := snowflake.ID()
	filepath := path.Join(folder, fmt.Sprintf("%d", headerFileId))

	var headers []Header
	for _, header := range headersMap {
		headers = append(headers, header)
	}

	headersFile := HeadersFile{
		KeyId:   s.keystore.LastKeyId,
		Bucket:  bucket,
		Headers: headers,
	}
	err := writeHeadersFile(store, safeName, filepath, s.keystore.Keys[s.keystore.LastKeyId], headersFile)
	if core.IsErr(err, nil, "cannot write headers: %v", err) {
		return
	}
	core.Info("Wrote merged headers to %s/%s", store, filepath)

	for _, header := range headersMap {
		res, err := sql.Exec("UPDATE_HEADER_FILE", sql.Args{
			"safe":       safeName,
			"bucket":     bucket,
			"fileId":     header.FileId,
			"headerFile": headerFileId,
		})
		if core.IsErr(err, nil, "cannot update header file: %v", err) {
			return
		}
		cnt, _ := res.RowsAffected()
		core.Info("Updated header file for %s/%s %d", store, header.Name, cnt)
	}

	for _, fileToDelete := range filesToDelete {
		store.Delete(fileToDelete)
		core.Info("Deleted header file %s/%s", store, filepath)
	}

	wg.Done()
}
