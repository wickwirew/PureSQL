CREATE TABLE foo (id INTEGER PRIMARY KEY, bar INTEGER AS Bool, baz TEXT NOT NULL);
CREATE TABLE bar (id INTEGER PRIMARY KEY, qux INTEGER AS Bool);

-- CHECK: SIGNATURE
-- CHECK:   PARAMETERS
-- CHECK:     PARAMETER
-- CHECK:       TYPE INTEGER
-- CHECK:       INDEX 1
-- CHECK:       NAME id
-- CHECK:   OUTPUT_CHUNKS
-- CHECK:     CHUNK
-- CHECK:       OUTPUT
-- CHECK:         id INTEGER
-- CHECK:         bar (INTEGER AS Bool)?
-- CHECK:         baz TEXT
-- CHECK:       OUTPUT_TABLE foo
-- CHECK:   TABLES
-- CHECK:     foo
SELECT * FROM foo WHERE id = ?;

-- CHECK: SIGNATURE
-- CHECK:   PARAMETERS
-- CHECK:     PARAMETER
-- CHECK:       TYPE (INTEGER AS Bool)?
-- CHECK:       INDEX 1
-- CHECK:       NAME bar
-- CHECK:   OUTPUT_CHUNKS
-- CHECK:     CHUNK
-- CHECK:       OUTPUT
-- CHECK:         id INTEGER
-- CHECK:         bar (INTEGER AS Bool)?
-- CHECK:   TABLES
-- CHECK:     foo
SELECT id, bar + 1 FROM foo WHERE bar * 20 > ?;

-- CHECK: SIGNATURE
-- CHECK:   PARAMETERS
-- CHECK:     PARAMETER
-- CHECK:       TYPE INTEGER
-- CHECK:       INDEX 1
-- CHECK:       NAME id
-- CHECK:     PARAMETER
-- CHECK:       TYPE (INTEGER AS Bool)?
-- CHECK:       INDEX 2
-- CHECK:       NAME bar
-- CHECK:   OUTPUT_CHUNKS
-- CHECK:     CHUNK
-- CHECK:       OUTPUT
-- CHECK:         id INTEGER
-- CHECK:         bar (INTEGER AS Bool)?
-- CHECK:         baz TEXT
-- CHECK:       OUTPUT_TABLE foo
-- CHECK:   TABLES
-- CHECK:     foo
SELECT * FROM foo WHERE id = :id AND id = :id AND bar = ?;

-- CHECK: SIGNATURE
-- CHECK:   PARAMETERS
-- CHECK:     PARAMETER
-- CHECK:       TYPE (INTEGER...)
-- CHECK:       INDEX 1
-- CHECK:       NAME theIds
-- CHECK:   OUTPUT_CHUNKS
-- CHECK:     CHUNK
-- CHECK:       OUTPUT
-- CHECK:         id INTEGER
-- CHECK:         bar (INTEGER AS Bool)?
-- CHECK:         baz TEXT
-- CHECK:       OUTPUT_TABLE foo
-- CHECK:   TABLES
-- CHECK:     foo
SELECT * FROM foo WHERE id IN (SELECT subFoo.id FROM foo AS subFoo WHERE subFoo.id IN :theIds);

-- CHECK: SIGNATURE
-- CHECK:   OUTPUT_CHUNKS
-- CHECK:     CHUNK
-- CHECK:       OUTPUT
-- CHECK:         id INTEGER
-- CHECK:         bar (INTEGER AS Bool)?
-- CHECK:         baz TEXT
-- CHECK:       OUTPUT_TABLE foo
-- CHECK:     CHUNK
-- CHECK:       OUTPUT
-- CHECK:         bazWithPostfix TEXT
-- CHECK:   TABLES
-- CHECK:     foo
SELECT foo.*, foo.baz || 'postfix' AS bazWithPostfix FROM foo;

-- CHECK: SIGNATURE
-- CHECK:   OUTPUT_CHUNKS
-- CHECK:     CHUNK
-- CHECK:       OUTPUT
-- CHECK:         bazButOnItsOwn TEXT
-- CHECK:     CHUNK
-- CHECK:       OUTPUT
-- CHECK:         id INTEGER
-- CHECK:         bar (INTEGER AS Bool)?
-- CHECK:         baz TEXT
-- CHECK:       OUTPUT_TABLE foo
-- CHECK:   TABLES
-- CHECK:     foo
SELECT foo.baz AS bazButOnItsOwn, foo.* FROM foo;

-- CHECK: SIGNATURE
-- CHECK:   OUTPUT_CHUNKS
-- CHECK:     CHUNK
-- CHECK:       OUTPUT
-- CHECK:         id INTEGER
-- CHECK:         bar (INTEGER AS Bool)?
-- CHECK:   TABLES
-- CHECK:     bar
-- CHECK:     foo
SELECT id, bar FROM foo
UNION
SELECT id, qux FROM bar;

-- CHECK: SIGNATURE
-- CHECK:   OUTPUT_CHUNKS
-- CHECK:     CHUNK
-- CHECK:       OUTPUT
-- CHECK:         id INTEGER
-- CHECK:         baz TEXT
-- CHECK:   TABLES
-- CHECK:     bar
-- CHECK:     foo
-- CHECK-ERROR: Unable to unify types 'TEXT' and '(INTEGER AS Bool)?'
SELECT id, baz FROM foo
UNION
SELECT id, qux FROM bar;

-- CHECK: SIGNATURE
-- CHECK:   OUTPUT_CHUNKS
-- CHECK:     CHUNK
-- CHECK:       OUTPUT
-- CHECK:         id INTEGER
-- CHECK:         bar (INTEGER AS Bool)?
-- CHECK:         baz TEXT
-- CHECK:   TABLES
-- CHECK:     bar
-- CHECK:     foo
-- CHECK-ERROR: SELECTs for UNION do not have the same number of columns (3 and 2)
SELECT id, bar, baz FROM foo
UNION
SELECT id, qux FROM bar;

-- CHECK: SIGNATURE
-- CHECK:   PARAMETERS
-- CHECK:     PARAMETER
-- CHECK:       TYPE (INTEGER AS Bool)?
-- CHECK:       INDEX 1
-- CHECK:       NAME param
-- CHECK:   OUTPUT_CHUNKS
-- CHECK:     CHUNK
-- CHECK:       OUTPUT
-- CHECK:         id INTEGER
-- CHECK:         param (INTEGER AS Bool)?
-- CHECK:   TABLES
-- CHECK:     bar
-- CHECK:     foo
SELECT id, ? AS param FROM foo
UNION
SELECT id, qux FROM bar;

-- CHECK: SIGNATURE
-- CHECK:   PARAMETERS
-- CHECK:     PARAMETER
-- CHECK:       TYPE (INTEGER AS Bool)?
-- CHECK:       INDEX 1
-- CHECK:       NAME value
-- CHECK:   OUTPUT_CHUNKS
-- CHECK:     CHUNK
-- CHECK:       OUTPUT
-- CHECK:         id INTEGER
-- CHECK:         bar (INTEGER AS Bool)?
-- CHECK:   TABLES
-- CHECK:     bar
-- CHECK:     foo
SELECT id, bar FROM foo
UNION
SELECT id, ? AS value FROM bar;

-- CHECK: SIGNATURE
-- CHECK:   OUTPUT_CHUNKS
-- CHECK:     CHUNK
-- CHECK:       OUTPUT
-- CHECK:         id INTEGER
-- CHECK:         bestValue INTEGER
-- CHECK:         secondBestValue INTEGER
-- CHECK:         thirdBestValue INTEGER
-- CHECK:   TABLES
-- CHECK:     bar
SELECT id,
    (bar.id + unixepoch()) + 1 AS bestValue,
    (bar.id) + (1 - 12) * (unixepoch()) AS secondBestValue,
    (bar.id) + (bar.id + 1) AS thirdBestValue
FROM bar;

-- CHECK: SIGNATURE
-- CHECK:   OUTPUT_CHUNKS
-- CHECK:     CHUNK
-- CHECK:       OUTPUT
-- CHECK:         id INTEGER
-- CHECK:         bar (INTEGER AS Bool)?
-- CHECK:         baz TEXT
-- CHECK:       OUTPUT_TABLE foo
-- CHECK:   TABLES
-- CHECK:     bar
-- CHECK:     foo
SELECT * FROM foo
WHERE id IN (SELECT qux FROM bar WHERE qux > foo.id);

-- CHECK: SIGNATURE
-- CHECK:   OUTPUT_CHUNKS
-- CHECK:     CHUNK
-- CHECK:       OUTPUT
-- CHECK:         id INTEGER
-- CHECK:         bar (INTEGER AS Bool)?
-- CHECK:         baz TEXT
-- CHECK:       OUTPUT_TABLE foo
-- CHECK:   TABLES
-- CHECK:     bar
-- CHECK:     foo
SELECT * FROM foo
WHERE id > (SELECT COUNT(*) FROM bar);

-- CHECK: SIGNATURE
-- CHECK:   OUTPUT_CHUNKS
-- CHECK:     CHUNK
-- CHECK:       OUTPUT
-- CHECK:         value INTEGER
-- CHECK:   TABLES
-- CHECK:     foo
SELECT -1 AS value FROM foo
WHERE value = 1 AND value NOTNULL AND value NOT NULL AND value ISNULL ORDER BY value;

-- CHECK: SIGNATURE
-- CHECK:   PARAMETERS
-- CHECK:     PARAMETER
-- CHECK:       TYPE INTEGER
-- CHECK:       INDEX 1
-- CHECK:       NAME limit
-- CHECK:   OUTPUT_CHUNKS
-- CHECK:     CHUNK
-- CHECK:       OUTPUT
-- CHECK:         value INTEGER
-- CHECK:   TABLES
-- CHECK:     foo
SELECT 1 AS value FROM foo
WHERE EXISTS (SELECT * FROM foo)
LIMIT ?;

-- CHECK: SIGNATURE
-- CHECK:   OUTPUT_CHUNKS
-- CHECK:     CHUNK
-- CHECK:       OUTPUT
-- CHECK:         isOne (INTEGER AS Bool)
-- CHECK:   TABLES
-- CHECK:     foo
SELECT id = 1 AS isOne FROM foo;
