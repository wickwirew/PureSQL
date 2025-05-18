CREATE TABLE user (id INTEGER, name TEXT);

-- CHECK: SIGNATURE
-- CHECK:   PARAMETERS
-- CHECK:     PARAMETER
-- CHECK:       TYPE INTEGER?
-- CHECK:       INDEX 1
-- CHECK:       NAME id
-- CHECK:     PARAMETER
-- CHECK:       TYPE TEXT?
-- CHECK:       INDEX 2
-- CHECK:       NAME name
-- CHECK:     TABLES
-- CHECK:       user
INSERT INTO user (id, name) VALUES (?, ?);

-- CHECK: SIGNATURE
-- CHECK:   PARAMETERS
-- CHECK:     PARAMETER
-- CHECK:       TYPE INTEGER?
-- CHECK:       INDEX 1
-- CHECK:       NAME id
-- CHECK:     PARAMETER
-- CHECK:       TYPE TEXT?
-- CHECK:       INDEX 2
-- CHECK:       NAME name
-- CHECK:   OUTPUT_CHUNKS
-- CHECK:     CHUNK
-- CHECK:       OUTPUT
-- CHECK:         id INTEGER?
-- CHECK:         name TEXT?
-- CHECK:     TABLES
-- CHECK:       user
INSERT INTO user (id, name) VALUES (?, ?) RETURNING *;

-- CHECK: SIGNATURE
-- CHECK:   PARAMETERS
-- CHECK:     PARAMETER
-- CHECK:       TYPE INTEGER?
-- CHECK:       INDEX 1
-- CHECK:       NAME id
-- CHECK:     PARAMETER
-- CHECK:       TYPE TEXT?
-- CHECK:       INDEX 2
-- CHECK:       NAME name
-- CHECK:     PARAMETER
-- CHECK:       TYPE INTEGER?
-- CHECK:       INDEX 3
-- CHECK:       NAME id2
-- CHECK:     PARAMETER
-- CHECK:       TYPE TEXT?
-- CHECK:       INDEX 4
-- CHECK:       NAME name2
-- CHECK:     PARAMETER
-- CHECK:       TYPE INTEGER?
-- CHECK:       INDEX 5
-- CHECK:       NAME id3
-- CHECK:     PARAMETER
-- CHECK:       TYPE TEXT?
-- CHECK:       INDEX 6
-- CHECK:       NAME name3
-- CHECK:   OUTPUT_CHUNKS
-- CHECK:     CHUNK
-- CHECK:       OUTPUT
-- CHECK:         id INTEGER?
-- CHECK:         name TEXT?
-- CHECK:     TABLES
-- CHECK:       user
INSERT INTO user (id, name) VALUES (?, ?), (?, ?), (?, ?) RETURNING *;
