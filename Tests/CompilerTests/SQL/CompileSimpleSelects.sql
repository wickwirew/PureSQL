CREATE TABLE foo (id INTEGER PRIMARY KEY, bar INTEGER AS Bool, baz TEXT NOT NULL);

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
SELECT id, bar + 1 FROM foo WHERE bar * 20 > ?;

-- CHECK: SIGNATURE
-- CHECK:   PARAMETERS
-- CHECK:     PARAMETER
-- CHECK:       TYPE INTEGER
-- CHECK:       INDEX 1
-- CHECK:       NAME :id
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
SELECT * FROM foo WHERE id = :id AND id = :id AND bar = ?;

-- CHECK: SIGNATURE
-- CHECK:   PARAMETERS
-- CHECK:     PARAMETER
-- CHECK:       TYPE (INTEGER...)
-- CHECK:       INDEX 1
-- CHECK:       NAME :theIds
-- CHECK:   OUTPUT_CHUNKS
-- CHECK:     CHUNK
-- CHECK:       OUTPUT
-- CHECK:         id INTEGER
-- CHECK:         bar (INTEGER AS Bool)?
-- CHECK:         baz TEXT
-- CHECK:       OUTPUT_TABLE foo
SELECT * FROM foo WHERE id IN (SELECT subFoo.id FROM foo AS subFoo WHERE subFoo.id IN :theIds);
