-- CHECK: TABLE
-- CHECK:   ...
CREATE TABLE foo (bar INTEGER);

CREATE UNIQUE INDEX
bar_index ON foo (bar) WHERE bar > 1;

CREATE INDEX IF NOT EXISTS
bar_index ON foo (bar) WHERE bar > 1;

-- CHECK-ERROR: Index with name already exists
CREATE INDEX bar_index ON foo (bar);

DROP INDEX bar_index;

CREATE INDEX bar_index ON foo (bar);

REINDEX bar_index;
REINDEX foo;
REINDEX main.foo;
REINDEX main.bar_index;
REINDEX;
-- CHECK-ERROR: No table or index with name
REINDEX dne;
