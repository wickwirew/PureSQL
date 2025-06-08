CREATE TABLE foo (bar INTEGER, baz TEXT);

-- CHECK: SIGNATURE
-- CHECK:   OUTPUT_CHUNKS
-- CHECK:     CHUNK
-- CHECK:       OUTPUT
-- CHECK:         bar INTEGER?
-- CHECK:         baz TEXT?
-- CHECK:       OUTPUT_TABLE foo
-- CHECK:   TABLES
-- CHECK:     foo
-- CHECK-ERROR: warn: Function returns the seconds as TEXT, not an INTEGER. Use unixepoch() instead
-- CHECK-ERROR: Unable to unify types 'INTEGER?' and 'TEXT'
SELECT * FROM foo WHERE bar = strftime('%s', 'now');

-- CHECK: SIGNATURE
-- CHECK:   OUTPUT_CHUNKS
-- CHECK:     CHUNK
-- CHECK:       OUTPUT
-- CHECK:         baz TEXT
-- CHECK:         baz TEXT
-- CHECK:   TABLES
-- CHECK:     foo
SELECT GROUP_CONCAT(baz), GROUP_CONCAT(baz, ',') FROM foo;

-- CHECK: SIGNATURE
-- CHECK:   OUTPUT_CHUNKS
-- CHECK:     CHUNK
-- CHECK:       OUTPUT
-- CHECK:         column1 INTEGER
-- CHECK:         column2 REAL
-- CHECK:         column3 REAL
-- CHECK:         bar INTEGER?
-- CHECK:   TABLES
-- CHECK:     foo
SELECT
-- CHECK-ERROR: warn: Integer division, result will not be floating point. 'CAST' or add '.0'
1 / 2,
1.0 / 2,
1 / 2.0,
-- CHECK-ERROR: warn: Integer division, result will not be floating point. 'CAST' or add '.0'
1 / bar
FROM foo;
