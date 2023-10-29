-- INIT
CREATE TABLE IF NOT EXISTS identities (
    id VARCHAR(256),
    data BLOB,
    trusted INTEGER,
    PRIMARY KEY(id)
);

-- INIT
CREATE INDEX IF NOT EXISTS idx_identities_trust ON identities(trusted);

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
CREATE TABLE IF NOT EXISTS Zone (
    portal TEXT PRIMARY KEY,
    name TEXT,
    value BLOB
);

-- GET_ZONES
SELECT name, value FROM Zone WHERE portal=:portal

-- SET_ZONE
INSERT INTO Zone(portal,name,value) VALUES(:portal,:name,:value)
  ON CONFLICT(portal) DO UPDATE SET value=:value, name=:name
  WHERE portal=:portal

-- DELETE_ZONE
DELETE FROM Zone WHERE portal=:portal AND name=:name

-- INIT
CREATE TABLE IF NOT EXISTS Header (
  safe TEXT NOT NULL,
  name TEXT NOT NULL,
  size INTEGER NOT NULL,
  fileId INTEGER NOT NULL,
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
  cacheExpires INTEGER,
  header BLOB,
  PRIMARY KEY (safe, name, fileId)
);

-- INIT
CREATE INDEX IF NOT EXISTS modTimeIndex ON Header (modTime);

-- INIT
CREATE INDEX IF NOT EXISTS fileIdIndex ON Header (fileId);

-- INIT
CREATE INDEX IF NOT EXISTS nameIndex ON Header (name);

-- INSERT_HEADER
INSERT INTO Header (safe, name, size, fileId, base, dir, depth, modTime, syncTime, tags, contentType, creator, privateId, deleted, cacheExpires, header)
VALUES (:safe, :name, :fileId, :size, :base, :dir, :depth, :modTime, :syncTime, :tags, :contentType, :creator, :privateId, :deleted, :cacheExpires, :header)
ON CONFLICT (safe, name, fileId)  DO NOTHING;

-- UPDATE_HEADER
UPDATE Header SET header = :header, cacheExpires=:cacheExpires WHERE safe = :safe AND fileId = :fileId

-- SET_DELETED_FILE
UPDATE Header SET deleted = 1 WHERE safe = :safe AND fileId = :fileId

-- GET_FILES_NAME
SELECT header FROM Header
WHERE safe = :safe
  AND (:name = '' OR name = :name)
  AND (:suffix = '' OR name LIKE '%' || :suffix)
  AND (:fileId = 0 OR fileId = :fileId)
  AND (:dir = '' OR dir = :dir)
  AND (:tags = '' OR tags LIKE '%' || :tags || '%')
  AND (:contentType = '' OR contentType = :contentType)
  AND (:creator = '' OR creator = :creator)
  AND (:noPrivate = 0 OR privateId == '')
  AND (:privateId = '' OR (privateId = :privateId AND creator = :currentUser) OR (privateId = :currentUser AND creator = :privateId))
  AND (:before < 0 OR modTime < :before)
  AND (:after < 0 OR modTime > :after)
  AND (:syncAfter < 0 OR syncTime > :syncAfter)
  AND (depth >= :fromDepth) 
  AND (:toDepth = 0 OR depth <= :toDepth)
  AND (:includeDeleted == 1 OR deleted = 0)
  ORDER BY name LIMIT CASE WHEN :limit = 0 THEN -1 ELSE :limit END OFFSET :offset

-- GET_FILES_MODTIME
SELECT header FROM Header
WHERE safe = :safe
  AND (:name = '' OR name = :name)
  AND (:suffix = '' OR name LIKE '%' || :suffix)
  AND (:fileId = 0 OR fileId = :fileId)
  AND (:dir = '' OR dir = :dir)
  AND (:tags = '' OR tags LIKE '%' || :tags || '%')
  AND (:contentType = '' OR contentType = :contentType)
  AND (:creator = '' OR creator = :creator)
  AND (:noPrivate = 0 OR privateId == '')
  AND (:privateId = '' OR (privateId = :privateId AND creator = :currentUser) OR (privateId = :currentUser AND creator = :privateId))
  AND (:before < 0 OR modTime < :before)
  AND (:after < 0 OR modTime > :after)
  AND (:syncAfter < 0 OR syncTime > :syncAfter)
  AND (depth >= :fromDepth) 
  AND (:toDepth = 0 OR depth <= :toDepth)
  AND (:includeDeleted == 1 OR deleted = 0)
  ORDER BY name LIMIT CASE WHEN :limit = 0 THEN -1 ELSE :limit END OFFSET :offset

-- GET_FILES_NAME_DESC
SELECT header FROM Header
WHERE safe = :safe
  AND (:name = '' OR name = :name)
  AND (:suffix = '' OR name LIKE '%' || :suffix)
  AND (:fileId = 0 OR fileId = :fileId)
  AND (:dir = '' OR dir = :dir)
  AND (:tags = '' OR tags LIKE '%' || :tags || '%')
  AND (:contentType = '' OR contentType = :contentType)
  AND (:creator = '' OR creator = :creator)
  AND (:noPrivate = 0 OR privateId == '')
  AND (:privateId = '' OR (privateId = :privateId AND creator = :currentUser) OR (privateId = :currentUser AND creator = :privateId))
  AND (:before < 0 OR modTime < :before)
  AND (:after < 0 OR modTime > :after)
  AND (:syncAfter < 0 OR syncTime > :syncAfter)
  AND (depth >= :fromDepth) 
  AND (:toDepth = 0 OR depth <= :toDepth)
  AND (:includeDeleted == 1 OR deleted = 0)
  ORDER BY name DESC LIMIT CASE WHEN :limit = 0 THEN -1 ELSE :limit END OFFSET :offset

-- GET_FILES_MODTIME_DESC
SELECT header FROM Header
WHERE safe = :safe
  AND (:name = '' OR name = :name)
  AND (:suffix = '' OR name LIKE '%' || :suffix)
  AND (:fileId = 0 OR fileId = :fileId)
  AND (:dir = '' OR dir = :dir)
  AND (:tags = '' OR tags LIKE '%' || :tags || '%')
  AND (:contentType = '' OR contentType = :contentType)
  AND (:creator = '' OR creator = :creator)
  AND (:noPrivate = 0 OR privateId == '')
  AND (:privateId = '' OR (privateId = :privateId AND creator = :currentUser) OR (privateId = :currentUser AND creator = :privateId))
  AND (:before < 0 OR modTime < :before)
  AND (:after < 0 OR modTime > :after)
  AND (:syncAfter < 0 OR syncTime > :syncAfter)
  AND (depth >= :fromDepth) 
  AND (:toDepth = 0 OR depth <= :toDepth)
  AND (:includeDeleted == 1 OR deleted = 0)
  ORDER BY name DESC LIMIT CASE WHEN :limit = 0 THEN -1 ELSE :limit END OFFSET :offset

-- GET_FOLDERS
SELECT distinct dir FROM Header
WHERE safe= :safe
  AND (:dir="" OR dir LIKE :dir || '/%')
  AND (depth >= :fromDepth) 
  AND (:toDepth = 0 OR depth <= :toDepth)

-- GET_LAST_HEADER
SELECT header
FROM Header
WHERE safe = :safe
  AND (:name = "" OR name = :name)
  AND (fileId = :fileId OR :fileId = 0)
ORDER BY modTime DESC
LIMIT 1;

-- GET_CACHE_EXPIRE
SELECT header FROM Header
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

-- DELETE_SAFE
DELETE FROM Header WHERE safe = :safe
