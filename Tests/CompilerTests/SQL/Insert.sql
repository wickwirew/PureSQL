CREATE TABLE user (id INTEGER, name TEXT);

-- CHECK: SIGNATURE
-- CHECK:   PARAMETERS
-- CHECK:     PARAMETER
-- CHECK:       TYPE ANY
-- CHECK:       INDEX 1
-- CHECK:       NAME id
-- CHECK:     PARAMETER
-- CHECK:       TYPE ANY
-- CHECK:       INDEX 2
-- CHECK:       NAME name
INSERT INTO user (id, name) VALUES (?, ?);
