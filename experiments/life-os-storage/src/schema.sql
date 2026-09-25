PRAGMA foreign_keys = ON;
PRAGMA journal_mode = WAL;
PRAGMA synchronous = FULL;
PRAGMA busy_timeout = 5000;
CREATE TABLE IF NOT EXISTS schema_version(version INTEGER PRIMARY KEY CHECK(version=1));
INSERT OR IGNORE INTO schema_version VALUES(1);
CREATE TABLE IF NOT EXISTS blobs(hash TEXT PRIMARY KEY, size INTEGER NOT NULL);
CREATE TABLE IF NOT EXISTS sources(
 id TEXT PRIMARY KEY, namespace TEXT NOT NULL, source_key TEXT NOT NULL,
 kind TEXT NOT NULL, UNIQUE(namespace,source_key));
CREATE TABLE IF NOT EXISTS source_versions(
 id TEXT PRIMARY KEY, source_id TEXT NOT NULL REFERENCES sources(id),
 revision INTEGER NOT NULL, blob_hash TEXT NOT NULL REFERENCES blobs(hash),
 received_at TEXT NOT NULL, metadata TEXT NOT NULL CHECK(json_valid(metadata)),
 UNIQUE(source_id,revision), UNIQUE(source_id,blob_hash));
CREATE TABLE IF NOT EXISTS records(
 id TEXT PRIMARY KEY, kind TEXT NOT NULL CHECK(kind IN
 ('document','times','knowledge','project','area','intent','task','session','review','resource','observation')),
 title TEXT NOT NULL, body TEXT NOT NULL, occurred_on TEXT,
 origin TEXT NOT NULL CHECK(origin IN ('import','owner','agent')),
 revision INTEGER NOT NULL DEFAULT 1, stale INTEGER NOT NULL DEFAULT 0 CHECK(stale IN(0,1)),
 metadata TEXT NOT NULL DEFAULT '{}' CHECK(json_valid(metadata)));
CREATE INDEX IF NOT EXISTS records_kind_date ON records(kind,occurred_on);
CREATE TABLE IF NOT EXISTS record_revisions(
 record_id TEXT NOT NULL REFERENCES records(id), revision INTEGER NOT NULL,
 body TEXT NOT NULL, title TEXT NOT NULL, reason TEXT NOT NULL, created_at TEXT NOT NULL,
 PRIMARY KEY(record_id,revision));
CREATE TABLE IF NOT EXISTS evidence(
 record_id TEXT NOT NULL REFERENCES records(id), source_version_id TEXT NOT NULL REFERENCES source_versions(id),
 locator TEXT NOT NULL, PRIMARY KEY(record_id,source_version_id,locator));
CREATE TABLE IF NOT EXISTS dependencies(
 derived_id TEXT NOT NULL REFERENCES records(id), parent_id TEXT NOT NULL REFERENCES records(id),
 parent_revision INTEGER NOT NULL, PRIMARY KEY(derived_id,parent_id), CHECK(derived_id != parent_id));
CREATE TABLE IF NOT EXISTS memberships(
 record_id TEXT NOT NULL REFERENCES records(id), entity_id TEXT NOT NULL REFERENCES records(id),
 PRIMARY KEY(record_id,entity_id), CHECK(record_id != entity_id));
CREATE TABLE IF NOT EXISTS intents(
 record_id TEXT PRIMARY KEY REFERENCES records(id),
 state TEXT NOT NULL CHECK(state IN ('candidate','deferred','active','cancelled')),
 condition TEXT NOT NULL);
CREATE TABLE IF NOT EXISTS tasks(
 record_id TEXT PRIMARY KEY REFERENCES records(id),
 state TEXT NOT NULL CHECK(state IN ('candidate','ready','running','done','cancelled')),
 authorization TEXT NOT NULL DEFAULT 'none' CHECK(authorization IN ('none','owner')),
 CHECK(state IN ('candidate','cancelled') OR authorization='owner'));
CREATE TABLE IF NOT EXISTS links(
 from_id TEXT NOT NULL REFERENCES records(id), target TEXT NOT NULL,
 to_id TEXT REFERENCES records(id), status TEXT NOT NULL CHECK(status IN ('resolved','missing','ambiguous','external')),
 PRIMARY KEY(from_id,target));
CREATE TABLE IF NOT EXISTS jobs(
 id TEXT PRIMARY KEY, record_id TEXT NOT NULL REFERENCES records(id),
 kind TEXT NOT NULL, state TEXT NOT NULL CHECK(state IN ('pending','done','failed')));
CREATE TABLE IF NOT EXISTS import_inventory(
 path TEXT PRIMARY KEY, disposition TEXT NOT NULL, reason TEXT NOT NULL,
 source_id TEXT REFERENCES sources(id));
CREATE VIRTUAL TABLE IF NOT EXISTS record_fts USING fts5(
 id UNINDEXED,title,body,tokenize='trigram');
CREATE TRIGGER IF NOT EXISTS record_insert AFTER INSERT ON records BEGIN
 INSERT INTO record_fts(id,title,body) VALUES(new.id,new.title,new.body);
END;
CREATE TRIGGER IF NOT EXISTS record_update AFTER UPDATE ON records BEGIN
 DELETE FROM record_fts WHERE id=old.id;
 INSERT INTO record_fts(id,title,body) VALUES(new.id,new.title,new.body);
END;
CREATE TRIGGER IF NOT EXISTS record_delete AFTER DELETE ON records BEGIN
 DELETE FROM record_fts WHERE id=old.id;
END;
