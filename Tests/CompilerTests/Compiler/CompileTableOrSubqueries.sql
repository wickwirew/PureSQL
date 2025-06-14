/*
TableOrSubquery seems to be the trickiest part of the AST
and want to have lots of tests validating it matches SQLite
even for the weird use cases.

Each test has a "SQLite Output" above it to show exact what SQLite
returns when run locally as a sanity check.

https://www.sqlite.org/syntax/table-or-subquery.html
 */

CREATE TABLE foo (bar INTEGER);
CREATE TABLE baz (qux INTEGER);

-- SQLite Output: bar | qux
-- CHECK: SIGNATURE
-- CHECK:   OUTPUT_CHUNKS
-- CHECK:     CHUNK
-- CHECK:       OUTPUT
-- CHECK:         bar INTEGER?
-- CHECK:       OUTPUT_TABLE foo
-- CHECK:     CHUNK
-- CHECK:       OUTPUT
-- CHECK:         qux INTEGER?
-- CHECK:       OUTPUT_TABLE baz
-- CHECK:   TABLES
-- CHECK:     baz
-- CHECK:     foo
SELECT * FROM (foo, baz);

-- SQLite Output: qux
-- CHECK: SIGNATURE
-- CHECK:   OUTPUT_CHUNKS
-- CHECK:     CHUNK
-- CHECK:       OUTPUT
-- CHECK:         qux INTEGER?
-- CHECK:       OUTPUT_TABLE quux
-- CHECK:   TABLES
-- CHECK:     baz
-- CHECK:     foo
SELECT quux.* FROM (foo, baz as quux);

-- SQLite Output: bar | qux
-- CHECK: SIGNATURE
-- CHECK:   OUTPUT_CHUNKS
-- CHECK:     CHUNK
-- CHECK:       OUTPUT
-- CHECK:         bar INTEGER?
-- CHECK:       OUTPUT_TABLE foo
-- CHECK:     CHUNK
-- CHECK:       OUTPUT
-- CHECK:         qux INTEGER?
-- CHECK:       OUTPUT_TABLE baz
-- CHECK:   TABLES
-- CHECK:     baz
-- CHECK:     foo
SELECT * FROM (foo CROSS JOIN baz);

-- SQLite Output: None due to error
-- CHECK: SIGNATURE
-- CHECK:   OUTPUT_CHUNKS
-- CHECK:     CHUNK
-- CHECK:       OUTPUT
-- CHECK:         qux INTEGER?
-- CHECK:       OUTPUT_TABLE quux
-- CHECK:     CHUNK
-- CHECK:       OUTPUT
-- CHECK:         bar INTEGER?
-- CHECK:       OUTPUT_TABLE foo
-- CHECK:   TABLES
-- CHECK:     baz
-- CHECK:     foo
-- CHECK-ERROR: 'foo' is ambigious in the current context
SELECT quux.*, foo.* FROM (foo CROSS JOIN baz AS quux, foo);

-- SQLite Output: bar | qux
-- CHECK: SIGNATURE
-- CHECK:   OUTPUT_CHUNKS
-- CHECK:     CHUNK
-- CHECK:       OUTPUT
-- CHECK:         bar INTEGER?
-- CHECK:       OUTPUT_TABLE foo
-- CHECK:     CHUNK
-- CHECK:       OUTPUT
-- CHECK:         qux INTEGER?
-- CHECK:       OUTPUT_TABLE baz
-- CHECK:   TABLES
-- CHECK:     baz
-- CHECK:     foo
SELECT * FROM (foo INNER JOIN baz ON bar = qux);

-- CHECK: SIGNATURE
-- CHECK:   OUTPUT_CHUNKS
-- CHECK:     CHUNK
-- CHECK:       OUTPUT
-- CHECK:         bar INTEGER?
-- CHECK:       OUTPUT_TABLE quux
-- CHECK:   TABLES
-- CHECK:     foo
SELECT quux.* FROM (foo AS quux);

-- CHECK: SIGNATURE
-- CHECK:   OUTPUT_CHUNKS
-- CHECK:     CHUNK
-- CHECK:       OUTPUT_TABLE foo
-- CHECK:   TABLES
-- CHECK:     foo
-- CHECK-ERROR: Table 'foo' does not exist
SELECT foo.* FROM (foo AS quux);

-- CHECK: SIGNATURE
-- CHECK:   OUTPUT_CHUNKS
-- CHECK:     CHUNK
-- CHECK:       OUTPUT
-- CHECK:         bar INTEGER?
-- CHECK:       OUTPUT_TABLE foo
-- CHECK:     CHUNK
-- CHECK:       OUTPUT
-- CHECK:         qux INTEGER?
-- CHECK:       OUTPUT_TABLE baz
-- CHECK:   TABLES
-- CHECK:     baz
-- CHECK:     foo
SELECT * FROM foo AS quux CROSS JOIN baz;

-- CHECK: SIGNATURE
-- CHECK:   OUTPUT_CHUNKS
-- CHECK:     CHUNK
-- CHECK:       OUTPUT
-- CHECK:         quux INTEGER?
-- CHECK:   TABLES
-- CHECK:     foo
SELECT quux FROM ((SELECT bar AS quux FROM foo));

/*
Comment at the end
*/
