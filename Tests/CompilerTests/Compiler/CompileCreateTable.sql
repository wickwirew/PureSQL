-- CHECK: TABLE
-- CHECK:   NAME foo
-- CHECK:   COLUMNS
-- CHECK:       KEY bar
-- CHECK:       VALUE INTEGER
-- CHECK:       KEY baz
-- CHECK:       VALUE TEXT?
-- CHECK:   PRIMARY_KEY
-- CHECK:     bar
-- CHECK:   KIND normal
CREATE TABLE foo (
    bar INTEGER PRIMARY KEY,
    baz TEXT
);

-- CHECK: TABLE
-- CHECK:   NAME bar
-- CHECK:   COLUMNS
-- CHECK:       KEY foo
-- CHECK:       VALUE TEXT?
-- CHECK:       KEY baz
-- CHECK:       VALUE TEXT?
-- CHECK:   PRIMARY_KEY
-- CHECK:     foo
-- CHECK:     baz
-- CHECK:   KIND normal
CREATE TABLE bar (
    foo TEXT,
    baz TEXT,
    PRIMARY KEY (foo, baz)
);

PRAGMA feather_require_strict_tables = TRUE;

-- CHECK: TABLE
-- CHECK:   NAME baz
-- CHECK:   COLUMNS
-- CHECK:       KEY foo
-- CHECK:       VALUE TEXT?
-- CHECK:   PRIMARY_KEY
-- CHECK:     foo
-- CHECK:   KIND normal
-- CHECK-ERROR: Missing STRICT table option
-- CHECK-ERROR: Column 'bar' does not exist
CREATE TABLE baz (
    foo TEXT,
    PRIMARY KEY (foo, bar)
);

-- CHECK: TABLE
-- CHECK:   NAME qux
-- CHECK:   COLUMNS
-- CHECK:       KEY foo
-- CHECK:       VALUE TEXT
-- CHECK:       KEY bar
-- CHECK:       VALUE INTEGER?
-- CHECK:   PRIMARY_KEY
-- CHECK:     bar
-- CHECK:   KIND normal
-- CHECK-ERROR: Table 'qux' already has a primary key
CREATE TABLE qux (
    foo TEXT PRIMARY KEY,
    bar INTEGER,
    PRIMARY KEY (bar)
) STRICT;

-- CHECK: TABLE
-- CHECK:   NAME PRIMARY
-- CHECK:   COLUMNS
-- CHECK:       KEY TABLE
-- CHECK:       VALUE KEY?
-- CHECK:   KIND normal
CREATE TABLE "PRIMARY" (
    "TABLE" INTEGER,
    [TABLE] `KEY`
) STRICT;
