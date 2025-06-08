CREATE TABLE foo (bar INTEGER);

-- CHECK: SIGNATURE
-- CHECK:   OUTPUT_CHUNKS
-- CHECK:     CHUNK
-- CHECK:       OUTPUT
-- CHECK:         bar INTEGER?
-- CHECK:       OUTPUT_TABLE foo
-- CHECK:   TABLES
-- CHECK:     foo
-- CHECK-ERROR: warn: Function returns the seconds as TEXT, not an INTEGER. Use unixepoch() instead
-- CHECK-ERROR: Unable to unify types 'INTEGER?' and 'TEXT'
SELECT * FROM foo WHERE bar = strftime('%s', 'now');
