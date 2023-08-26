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
CREATE TABLE IF NOT EXISTS File (
  portal TEXT NOT NULL,
  zone TEXT NOT NULL,
  name TEXT NOT NULL,
  short TEXT NOT NULL,
  depth INTEGER NOT NULL,
  ymd TEXT NOT NULL,
  bodyId INTEGER NOT NULL,
  modTime INTEGER NOT NULL,
  folder TEXT,
  tags TEXT,
  contentType TEXT,
  deleted INTEGER,
  cacheExpires INTEGER,
  header BLOB,
  PRIMARY KEY (portal, zone, name, ymd, bodyId)
);

-- SET_FILE
INSERT INTO File (portal, zone, name, short, depth, ymd, bodyId, modTime, folder, tags, contentType, header, deleted, cacheExpires)
VALUES (:portal, :zone, :name, :short, :depth, :ymd, :bodyId, :modTime, :folder, :tags, :contentType, :header, :deleted, :cacheExpires)
ON CONFLICT (portal, zone, name, ymd, bodyId)
DO UPDATE SET depth=:depth, modTime = :modTime, folder = :folder, tags = :tags, contentType = :contentType, deleted=:deleted, cacheExpires=:cacheExpires, header = :header

-- SET_DELETED_FILE
UPDATE File SET deleted = 1 WHERE portal = :portal AND zone = :zone AND name = :name AND ymd = :ymd AND bodyId = :bodyId

-- GET_FILES
SELECT header FROM File
WHERE portal = :portal
  AND zone = :zone
  AND (:name = '' OR name = :name)
  AND (:suffix = '' OR name LIKE '%' || :suffix)
  AND (:bodyId = 0 OR bodyId = :bodyId)
  AND (:folder = '' OR folder = :folder)
  AND (:tags = '' OR tags LIKE '%' || :tags || '%')
  AND (:contentType = '' OR contentType = :contentType)
  AND (:before < 0 OR modTime < :before)
  AND (:after < 0 OR modTime > :after)
  AND (:includeDeleted == 1 OR deleted = 0)
ORDER BY modTime DESC
LIMIT CASE WHEN :limit = 0 THEN -1 ELSE :limit END OFFSET :offset

-- GET_FOLDERS
SELECT distinct folder FROM File
WHERE portal= :portal
  AND zone = :zone
  AND folder LIKE :folder || '/%'
  AND depth = :depth

-- GET_LAST_YMD
SELECT ymd
FROM File
WHERE portal = :portal
  AND zone = :zone
ORDER BY ymd DESC
LIMIT 1

-- GET_FILE_BODY_ID
SELECT bodyId
FROM File
WHERE portal = :portal
  AND zone = :zone
  AND ymd >= :ymd

-- GET_LAST_FILE
SELECT header
FROM File
WHERE portal = :portal
  AND zone = :zone
  AND name = :name
  AND (bodyId = :bodyId OR :bodyId = 0)
ORDER BY modTime DESC
LIMIT 1;

-- GET_CACHE_EXPIRE
SELECT header FROM File
WHERE cacheExpires > 0
ORDER BY cacheExpires ASC
LIMIT 1;
