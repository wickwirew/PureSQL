CREATE TABLE foo (bar INTEGER);

-- CHECK: SIGNATURE
-- CHECK:   ...
SELECT * FROM foo;

DROP TABLE foo;

-- CHECK: SIGNATURE
-- CHECK:   ...
-- CHECK-ERROR: Table 'foo' does not exist
SELECT * FROM foo;
