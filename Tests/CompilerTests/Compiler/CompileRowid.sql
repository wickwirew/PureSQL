CREATE TABLE foo (id INTEGER PRIMARY KEY, name TEXT NOT NULL);
CREATE TABLE no_rowid (a TEXT NOT NULL, b TEXT NOT NULL, PRIMARY KEY (a)) WITHOUT ROWID;

-- `rowid` is not part of the generated output of `SELECT *`.
-- CHECK: SIGNATURE
-- CHECK:   OUTPUT_CHUNKS
-- CHECK:     CHUNK
-- CHECK:       OUTPUT
-- CHECK:         id INTEGER
-- CHECK:         name TEXT
-- CHECK:       OUTPUT_TABLE foo
-- CHECK:   TABLES
-- CHECK:     foo
SELECT * FROM foo;

-- `rowid` is available at query time, in both the result and the filter.
-- CHECK: SIGNATURE
-- CHECK:   PARAMETERS
-- CHECK:     PARAMETER
-- CHECK:       TYPE INTEGER
-- CHECK:       INDEX 1
-- CHECK:       NAME rid
-- CHECK:   OUTPUT_CHUNKS
-- CHECK:     CHUNK
-- CHECK:       OUTPUT
-- CHECK:         rowid INTEGER
-- CHECK:         name TEXT
-- CHECK:   TABLES
-- CHECK:     foo
SELECT rowid, name FROM foo WHERE rowid = :rid;

-- WITHOUT ROWID tables have no `rowid` column.
-- CHECK: SIGNATURE
-- CHECK:   OUTPUT_CHUNKS
-- CHECK:     CHUNK
-- CHECK:       OUTPUT
-- CHECK:         rowid <<error>>
-- CHECK:   TABLES
-- CHECK:     no_rowid
-- CHECK-ERROR: Column 'rowid' does not exist
SELECT rowid FROM no_rowid;
