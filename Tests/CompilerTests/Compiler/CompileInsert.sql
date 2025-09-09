CREATE TABLE user (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT,
    age INTEGER NOT NULL DEFAULT 0,
    description TEXT GENERATED ALWAYS AS (name || 'is a user')
);

-- CHECK: SIGNATURE
-- CHECK:   PARAMETERS
-- CHECK:     PARAMETER
-- CHECK:       TYPE INTEGER
-- CHECK:       INDEX 1
-- CHECK:       NAME id
-- CHECK:     PARAMETER
-- CHECK:       TYPE TEXT?
-- CHECK:       INDEX 2
-- CHECK:       NAME name
-- CHECK:     PARAMETER
-- CHECK:       TYPE INTEGER
-- CHECK:       INDEX 3
-- CHECK:       NAME age
-- CHECK:     TABLES
-- CHECK:       user
INSERT INTO user (id, name, age) VALUES (?, ?, ?);

-- CHECK: SIGNATURE
-- CHECK:   PARAMETERS
-- CHECK:     PARAMETER
-- CHECK:       TYPE INTEGER
-- CHECK:       INDEX 1
-- CHECK:       NAME id
-- CHECK:     PARAMETER
-- CHECK:       TYPE TEXT?
-- CHECK:       INDEX 2
-- CHECK:       NAME name
-- CHECK:   OUTPUT_CHUNKS
-- CHECK:     CHUNK
-- CHECK:       OUTPUT
-- CHECK:         id INTEGER
-- CHECK:         name TEXT?
-- CHECK:         age INTEGER
-- CHECK:         description TEXT?
-- CHECK:     TABLES
-- CHECK:       user
INSERT INTO user (id, name) VALUES (?, ?) RETURNING *;

-- CHECK: SIGNATURE
-- CHECK:   PARAMETERS
-- CHECK:     PARAMETER
-- CHECK:       TYPE INTEGER
-- CHECK:       INDEX 1
-- CHECK:       NAME id
-- CHECK:     PARAMETER
-- CHECK:       TYPE TEXT?
-- CHECK:       INDEX 2
-- CHECK:       NAME name
-- CHECK:     PARAMETER
-- CHECK:       TYPE INTEGER
-- CHECK:       INDEX 3
-- CHECK:       NAME id2
-- CHECK:     PARAMETER
-- CHECK:       TYPE TEXT?
-- CHECK:       INDEX 4
-- CHECK:       NAME name2
-- CHECK:     PARAMETER
-- CHECK:       TYPE INTEGER
-- CHECK:       INDEX 5
-- CHECK:       NAME id3
-- CHECK:     PARAMETER
-- CHECK:       TYPE TEXT?
-- CHECK:       INDEX 6
-- CHECK:       NAME name3
-- CHECK:   OUTPUT_CHUNKS
-- CHECK:     CHUNK
-- CHECK:       OUTPUT
-- CHECK:         id INTEGER
-- CHECK:         name TEXT?
-- CHECK:         age INTEGER
-- CHECK:         description TEXT?
-- CHECK:     TABLES
-- CHECK:       user
INSERT INTO user (id, name) VALUES (?, ?), (?, ?), (?, ?) RETURNING *;

-- CHECK: SIGNATURE
-- CHECK:   PARAMETERS
-- CHECK:     PARAMETER
-- CHECK:       TYPE INTEGER
-- CHECK:       INDEX 1
-- CHECK:       NAME id
-- CHECK:     PARAMETER
-- CHECK:       TYPE TEXT?
-- CHECK:       INDEX 2
-- CHECK:       NAME name
-- CHECK:     PARAMETER
-- CHECK:       TYPE INTEGER
-- CHECK:       INDEX 3
-- CHECK:       NAME age
-- CHECK:     TABLES
-- CHECK:       user
INSERT INTO user VALUES (?, ?, ?);

-- CHECK: SIGNATURE
-- CHECK:   PARAMETERS
-- CHECK:     PARAMETER
-- CHECK:       TYPE INTEGER
-- CHECK:       INDEX 1
-- CHECK:       NAME id
-- CHECK:     PARAMETER
-- CHECK:       TYPE TEXT?
-- CHECK:       INDEX 2
-- CHECK:       NAME name
-- CHECK:     PARAMETER
-- CHECK:       TYPE TEXT?
-- CHECK:       INDEX 3
-- CHECK:       NAME description
-- CHECK:   TABLES
-- CHECK:     user
-- CHECK-ERROR: Column is generated and not able to be set
INSERT INTO user (id, name, description) VALUES (?, ?, ?);

-- CHECK: SIGNATURE
-- CHECK:   PARAMETERS
-- CHECK:     PARAMETER
-- CHECK:       TYPE TEXT?
-- CHECK:       INDEX 1
-- CHECK:       NAME name
-- CHECK:     PARAMETER
-- CHECK:       TYPE INTEGER
-- CHECK:       INDEX 2
-- CHECK:       NAME id
-- CHECK:     TABLES
-- CHECK:       user
INSERT INTO user (name, id) VALUES (?, ?);

-- CHECK: SIGNATURE
-- CHECK:   PARAMETERS
-- CHECK:     PARAMETER
-- CHECK:       TYPE TEXT?
-- CHECK:       INDEX 1
-- CHECK:       NAME name
-- CHECK:     TABLES
-- CHECK:       user
INSERT INTO user (name) VALUES (?);

-- CHECK: SIGNATURE
-- CHECK:   PARAMETERS
-- CHECK:     PARAMETER
-- CHECK:       TYPE INTEGER
-- CHECK:       INDEX 1
-- CHECK:       NAME id
-- CHECK:     PARAMETER
-- CHECK:       TYPE TEXT?
-- CHECK:       INDEX 2
-- CHECK:       NAME name
-- CHECK:   TABLES
-- CHECK:     user
INSERT INTO user (id, name) VALUES (?, ?)
ON CONFLICT (id) DO UPDATE
SET name = excluded.name
WHERE excluded.name = 'bob';

-- CHECK: SIGNATURE
-- CHECK:   OUTPUT_CHUNKS
-- CHECK:     CHUNK
-- CHECK:       OUTPUT
-- CHECK:         id INTEGER
-- CHECK:   TABLES
-- CHECK:     user
INSERT INTO user (name) VALUES ('joe') RETURNING id;

CREATE TABLE foo (
    bar INTEGER,
    baz INTEGER,
    PRIMARY KEY (bar, baz)
);

-- CHECK: SIGNATURE
-- CHECK:   PARAMETERS
-- CHECK:     PARAMETER
-- CHECK:       TYPE INTEGER?
-- CHECK:       INDEX 1
-- CHECK:       NAME bar
-- CHECK:     PARAMETER
-- CHECK:       TYPE INTEGER?
-- CHECK:       INDEX 2
-- CHECK:       NAME baz
-- CHECK:   TABLES
-- CHECK:     foo
INSERT INTO foo VALUES (?, ?)
ON CONFLICT (bar, baz) DO NOTHING;
