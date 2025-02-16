CREATE TABLE foo (bar INTEGER, baz INTEGER);

-- CHECK: SIGNATURE
-- CHECK:   PARAMETERS
-- CHECK:     PARAMETER
-- CHECK:       TYPE INTEGER?
-- CHECK:       INDEX 1
-- CHECK:       NAME bar
UPDATE foo SET bar = ?;

-- CHECK: SIGNATURE
-- CHECK:   PARAMETERS
-- CHECK:     PARAMETER
-- CHECK:       TYPE INTEGER?
-- CHECK:       INDEX 1
-- CHECK:       NAME bar
-- CHECK:     PARAMETER
-- CHECK:       TYPE INTEGER?
-- CHECK:       INDEX 2
-- CHECK:       NAME :value
-- CHECK:     PARAMETER
-- CHECK:       TYPE INTEGER?
-- CHECK:       INDEX 3
-- CHECK:       NAME :condition
UPDATE foo SET bar = ?, baz = :value WHERE :condition = bar;

-- CHECK: SIGNATURE
-- CHECK:   PARAMETERS
-- CHECK:     PARAMETER
-- CHECK:       TYPE INTEGER?
-- CHECK:       INDEX 1
-- CHECK:     PARAMETER
-- CHECK:       TYPE INTEGER?
-- CHECK:       INDEX 2
UPDATE foo SET (bar, baz) = (?, ?);

-- CHECK: SIGNATURE
-- CHECK:   PARAMETERS
-- CHECK:     PARAMETER
-- CHECK:       TYPE INTEGER?
-- CHECK:       INDEX 1
-- CHECK:       NAME bar
-- CHECK:   OUTPUT
-- CHECK:     bar INTEGER?
-- CHECK:     baz INTEGER?
UPDATE foo SET bar = ? RETURNING *;
