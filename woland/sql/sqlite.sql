-- INIT
CREATE TABLE IF NOT EXISTS identities (
    id VARCHAR(256),
    data BLOB,
    PRIMARY KEY(id)
);

-- GET_IDENTITIES
SELECT data FROM identities

-- GET_IDENTITY
SELECT data FROM identities WHERE id=:id

-- DEL_IDENTITY
DELETE FROM identities WHERE id=:id

-- SET_IDENTITY
INSERT INTO identities(id,data) VALUES(:id,:data)
    ON CONFLICT(id) DO UPDATE SET data=:data
	WHERE id=:id

-- INIT
CREATE TABLE IF NOT EXISTS configs (
    node VARCHAR(128) NOT NULL, 
    k VARCHAR(64) NOT NULL, 
    s VARCHAR(64) NOT NULL,
    i INTEGER NOT NULL,
    b TEXT,
    CONSTRAINT pk_safe_key PRIMARY KEY(node,k)
);

-- GET_CONFIG
SELECT s, i, b FROM configs WHERE node=:node AND k=:key

-- SET_CONFIG
INSERT INTO configs(node,k,s,i,b) VALUES(:node,:key,:s,:i,:b)
	ON CONFLICT(node,k) DO UPDATE SET s=:s,i=:i,b=:b
	WHERE node=:node AND k=:key

-- DEL_CONFIG
DELETE FROM configs WHERE node=:node

-- INIT
CREATE TABLE IF NOT EXISTS Users (
  safe TEXT NOT NULL,
  id TEXT NOT NULL,
  permission INTEGER NOT NULL,
  PRIMARY KEY (safe, id)
);

-- GET_USERS
SELECT id, permission FROM Users WHERE safe=:safe

-- INSERT_USER
INSERT INTO Users(safe,id,permission) VALUES(:safe,:id,:permission)

-- SET_USER
INSERT INTO Users(safe,id,permission) VALUES(:safe,:id,:permission)
  ON CONFLICT(safe,id) DO UPDATE SET permission=:permission
  WHERE safe=:safe AND id=:id

-- INIT
CREATE TABLE IF NOT EXISTS Header (
  safe TEXT NOT NULL,
  bucket TEXT NOT NULL,
  name TEXT NOT NULL,
  size INTEGER NOT NULL,
  fileId INTEGER NOT NULL,
  headerFile INTEGER NOT NULL,
  base TEXT NOT NULL,
  dir TEXT,
  depth INTEGER NOT NULL,
  modTime INTEGER NOT NULL,
  syncTime INTEGER NOT NULL,
  tags TEXT,
  contentType TEXT,
  creator TEXT,
  privateId TEXT,
  deleted INTEGER,
  uploading INTEGER,
  cacheExpires INTEGER,
  header BLOB,
  PRIMARY KEY (safe, bucket, name, fileId)
);

-- INIT
CREATE INDEX IF NOT EXISTS modTimeIndex ON Header (modTime);

-- INIT
CREATE INDEX IF NOT EXISTS fileIdIndex ON Header (fileId);

-- INIT
CREATE INDEX IF NOT EXISTS nameIndex ON Header (name);

-- INSERT_HEADER
INSERT INTO Header (safe, bucket, name, headerFile, fileId, size, base, dir, depth, modTime, syncTime, tags, contentType, creator, privateId, deleted, uploading, cacheExpires, header)
VALUES (:safe, :bucket, :name, :headerFile, :fileId, :size, :base, :dir, :depth, :modTime, :syncTime, :tags, :contentType, :creator, :privateId, :deleted, :uploading, :cacheExpires, :header)
ON CONFLICT (safe, bucket, name, fileId) DO UPDATE SET headerFile = :headerFile;

-- UPDATE_HEADER
UPDATE Header SET header = :header, cacheExpires=:cacheExpires, uploading=:uploading WHERE safe = :safe AND bucket = :bucket AND fileId = :fileId

-- UPDATE_HEADER_FILE
UPDATE Header SET headerFile = :headerFile WHERE safe = :safe AND bucket = :bucket AND fileId = :fileId

-- DELETE_HEADER
DELETE FROM Header WHERE safe = :safe AND bucket = :bucket AND headerFile = :headerFile

-- SET_DELETED_FILE
UPDATE Header SET deleted = 1 WHERE safe = :safe AND fileId = :fileId

-- GET_HEADERS_IDS
SELECT headerFile, COUNT(*) as recordCount
FROM Header
WHERE safe = :safe AND bucket = :bucket
GROUP BY headerFile;

-- GET_HEADER_BY_FILE_NAME
SELECT header FROM Header
WHERE safe = :safe
  AND bucket = :bucket
  AND (:name = '' OR name = :name)
  AND (:name <> '' OR dir = :dir)
  AND (:prefix = '' OR name LIKE :prefix || '%')
  AND (:suffix = '' OR name LIKE '%' || :suffix)
  AND (:fileId = 0 OR fileId = :fileId)
  AND (:tags = '' OR tags LIKE '%' || :tags || '%')
  AND (:contentType = '' OR contentType = :contentType)
  AND (:creator = '' OR creator = :creator)
  AND (:noPrivate = 0 OR privateId == '')
  AND (:privateId = '' OR (privateId = :privateId AND creator = :currentUser) OR (privateId = :currentUser AND creator = :privateId))
  AND (:before < 0 OR modTime < :before)
  AND (:after < 0 OR modTime > :after)
  AND (depth = :depth)
  AND (:syncAfter < 0 OR syncTime > :syncAfter)
  AND (:includeDeleted == 1 OR deleted = 0)
  ORDER BY name LIMIT CASE WHEN :limit = 0 THEN -1 ELSE :limit END OFFSET :offset

-- GET_HEADER_BY_MODTIME
SELECT header FROM Header
WHERE safe = :safe
  AND bucket = :bucket
  AND (:name = '' OR name = :name)
  AND (:name <> '' OR dir = :dir)
  AND (:prefix = '' OR name LIKE :prefix || '%')
  AND (:suffix = '' OR name LIKE '%' || :suffix)
  AND (:fileId = 0 OR fileId = :fileId)
  AND (:tags = '' OR tags LIKE '%' || :tags || '%')
  AND (:contentType = '' OR contentType = :contentType)
  AND (:creator = '' OR creator = :creator)
  AND (:noPrivate = 0 OR privateId == '')
  AND (:privateId = '' OR (privateId = :privateId AND creator = :currentUser) OR (privateId = :currentUser AND creator = :privateId))
  AND (:before < 0 OR modTime < :before)
  AND (:after < 0 OR modTime > :after)
  AND (depth = :depth)
  AND (:syncAfter < 0 OR syncTime > :syncAfter)
  AND (:includeDeleted == 1 OR deleted = 0)
  ORDER BY modTime LIMIT CASE WHEN :limit = 0 THEN -1 ELSE :limit END OFFSET :offset

-- GET_HEADER_BY_FILE_NAME_DESC
SELECT header FROM Header
WHERE safe = :safe
  AND bucket = :bucket
  AND (:name = '' OR name = :name)
  AND (:name <> '' OR dir = :dir)
  AND (:prefix = '' OR name LIKE :prefix || '%')
  AND (:suffix = '' OR name LIKE '%' || :suffix)
  AND (:fileId = 0 OR fileId = :fileId)
  AND (:tags = '' OR tags LIKE '%' || :tags || '%')
  AND (:contentType = '' OR contentType = :contentType)
  AND (:creator = '' OR creator = :creator)
  AND (:noPrivate = 0 OR privateId == '')
  AND (:privateId = '' OR (privateId = :privateId AND creator = :currentUser) OR (privateId = :currentUser AND creator = :privateId))
  AND (:before < 0 OR modTime < :before)
  AND (:after < 0 OR modTime > :after)
  AND (depth = :depth)
  AND (:syncAfter < 0 OR syncTime > :syncAfter)
  AND (:includeDeleted == 1 OR deleted = 0)
  ORDER BY name DESC LIMIT CASE WHEN :limit = 0 THEN -1 ELSE :limit END OFFSET :offset

-- GET_HEADER_BY_MODTIME_DESC
SELECT header FROM Header
WHERE safe = :safe
  AND bucket = :bucket
  AND (:name = '' OR name = :name)
  AND (:name <> '' OR dir = :dir)
  AND (:prefix = '' OR name LIKE :prefix || '%')
  AND (:suffix = '' OR name LIKE '%' || :suffix)
  AND (:fileId = 0 OR fileId = :fileId)
  AND (:tags = '' OR tags LIKE '%' || :tags || '%')
  AND (:contentType = '' OR contentType = :contentType)
  AND (:creator = '' OR creator = :creator)
  AND (:noPrivate = 0 OR privateId == '')
  AND (:privateId = '' OR (privateId = :privateId AND creator = :currentUser) OR (privateId = :currentUser AND creator = :privateId))
  AND (:before < 0 OR modTime < :before)
  AND (:after < 0 OR modTime > :after)
  AND (depth = :depth)
  AND (:syncAfter < 0 OR syncTime > :syncAfter)
  AND (:includeDeleted == 1 OR deleted = 0)
  ORDER BY modTime DESC LIMIT CASE WHEN :limit = 0 THEN -1 ELSE :limit END OFFSET :offset

-- GET_FOLDERS
SELECT distinct dir FROM Header
WHERE safe= :safe
  AND bucket = :bucket
  AND (:dir="" OR dir LIKE :dir || '/%')
  AND (depth >= :fromDepth) 
  AND (depth <= :toDepth)

-- GET_LAST_HEADER
SELECT header
FROM Header
WHERE safe = :safe
  AND bucket = :bucket
  AND (:name = "" OR name = :name)
  AND (fileId = :fileId OR :fileId = 0)
ORDER BY modTime DESC
LIMIT 1;

-- GET_BUCKETS
SELECT distinct bucket
FROM Header
WHERE safe = :safe

-- GET_UPLOADS
SELECT headerFile, bucket, header FROM Header
WHERE safe = :safe AND uploading == 1
ORDER BY modTime DESC;

-- GET_CACHE_EXPIRE
SELECT safe, bucket, header FROM Header
WHERE cacheExpires > 0
ORDER BY cacheExpires ASC
LIMIT 1;

-- GET_SAFE_SIZE
SELECT IFNULL(SUM(size), 0) FROM Header WHERE safe LIKE :quoteGroup || '%' AND deleted = 0;

-- GET_OLDEST_FILE
SELECT safe, fileId, dir, size  FROM Header
WHERE safe LIKE :quoteGroup || '%' AND deleted = 0
ORDER BY modTime ASC
LIMIT 1;

-- DELETE_SAFE_HEADERS
DELETE FROM Header WHERE safe = :safe;

-- DELETE_SAFE_USERS
DELETE FROM Users WHERE safe = :safe;

-- DELETE_SAFE_CONFIGS
DELETE FROM configs WHERE k LIKE :safe || '/%';

-- DROP_IDENTITIES_TABLE
DELETE FROM identities;

-- DROP_HEADERS_TABLE
DELETE FROM Header;

-- DROP_USERS_TABLE
DELETE FROM Users;

-- DROP_CONFIGS_TABLE
DELETE FROM configs;
