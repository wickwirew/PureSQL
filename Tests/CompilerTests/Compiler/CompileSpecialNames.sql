CREATE TABLE foo (bar INTEGER, baz INTEGER);

-- CHECK: ...
-- CHECK: NAME bars
SELECT * FROM foo
WHERE bar IN ?;

-- CHECK: ...
-- CHECK: NAME barLower
-- CHECK: ...
-- CHECK: NAME barUpper
-- CHECK: ...
SELECT * FROM foo
WHERE bar BETWEEN ? AND ?;
