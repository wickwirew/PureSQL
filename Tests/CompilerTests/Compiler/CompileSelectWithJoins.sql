CREATE TABLE user (
    id INTEGER PRIMARY KEY,
    firstName TEXT NOT NULL,
    lastName TEXT NOT NULL,
    age INTEGER,
    fullName TEXT NOT NULL GENERATED ALWAYS AS (firstName || ' ' || lastName) VIRTUAL
);

CREATE TABLE pet (
    id INTEGER PRIMARY KEY,
    ownerId INTEGER REFERENCES user,
    name TEXT NOT NULL
);

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
-- CHECK:         fullName TEXT
-- CHECK:         name TEXT?
-- CHECK:   TABLES
-- CHECK:     pet
-- CHECK:     user
SELECT user.id, fullName, pet.name FROM user
JOIN pet ON user.id = pet.ownerId
WHERE user.id = ?;

-- CHECK: SIGNATURE
-- CHECK:   OUTPUT_CHUNKS
-- CHECK:     CHUNK
-- CHECK:       OUTPUT
-- CHECK:         id INTEGER
-- CHECK:         petName TEXT
-- CHECK:   TABLES
-- CHECK:     pet
-- CHECK:     user
-- CHECK-ERROR: 'id' is ambigious in the current context
SELECT id, pet.name AS petName FROM user
INNER JOIN pet ON user.id = pet.ownerId;
