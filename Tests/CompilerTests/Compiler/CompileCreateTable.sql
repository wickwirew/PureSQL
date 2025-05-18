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
-- CHECK:       VALUE DECIMAL?
-- CHECK:   PRIMARY_KEY
-- CHECK:     foo
-- CHECK:   KIND normal
-- CHECK-ERROR: Missing STRICT table option
-- CHECK-ERROR: Invalid type 'DECIMAL'
-- CHECK-ERROR: Column 'bar' does not exist
CREATE TABLE baz (
    foo DECIMAL,
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
-- CHECK-ERROR: Invalid type 'KEY'
CREATE TABLE "PRIMARY" (
    "TABLE" INTEGER,
    [TABLE] `KEY`
) STRICT;

-- CHECK: TABLE
-- CHECK:   NAME allValidTypes
-- CHECK:   COLUMNS
-- CHECK:       KEY int
-- CHECK:       VALUE INT?
-- CHECK:       KEY integer
-- CHECK:       VALUE INTEGER?
-- CHECK:       KEY text
-- CHECK:       VALUE TEXT?
-- CHECK:       KEY blob
-- CHECK:       VALUE BLOB?
-- CHECK:       KEY any
-- CHECK:       VALUE ANY?
-- CHECK:   KIND normal
CREATE TABLE allValidTypes (
    int INT,
    integer INTEGER,
    text TEXT,
    blob BLOB,
    any ANY
) STRICT;

-- CHECK: TABLE
-- CHECK:   NAME hasGenerated
-- CHECK:   COLUMNS
-- CHECK:       KEY foo
-- CHECK:       VALUE INTEGER?
-- CHECK:       KEY bar
-- CHECK:       VALUE INTEGER?
-- CHECK:       KEY baz
-- CHECK:       VALUE INTEGER?
-- CHECK:       KEY ref
-- CHECK:       VALUE INTEGER?
-- CHECK:   KIND normal
-- CHECK-ERROR: Column 'qux' does not exist
-- CHECK-ERROR: Table 'dne' does not exist
CREATE TABLE hasGenerated (
    foo INTEGER,
    bar INTEGER GENERATED ALWAYS AS (foo + 1),
    baz INTEGER GENERATED ALWAYS AS (qux + 1),
    ref INTEGER REFERENCES dne (value)
) STRICT;

-- CHECK: TABLE
-- CHECK:   NAME hasTableCheck
-- CHECK:   COLUMNS
-- CHECK:       KEY foo
-- CHECK:       VALUE INTEGER?
-- CHECK:       KEY bar
-- CHECK:       VALUE INTEGER?
-- CHECK:   KIND normal
-- CHECK-ERROR: Column 'foooooo' does not exist
-- CHECK-ERROR: Column 'typo' does not exist
-- CHECK-ERROR: Table 'doesNotExist' does not exist
CREATE TABLE hasTableCheck (
    foo INTEGER,
    bar INTEGER,
    CHECK (foo + bar > 1),
    CHECK (foooooo + bar > 1),
    FOREIGN KEY (typo) REFERENCES doesNotExist (meh),
    FOREIGN KEY (foo) REFERENCES hasGenerated (foo)
) STRICT;
