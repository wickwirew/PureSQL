-- CHECK: DELETE_STMT_SYNTAX
-- CHECK:   CTE_RECURSIVE false
-- CHECK:   TABLE
-- CHECK:     TABLE_NAME
-- CHECK:       SCHEMA main
-- CHECK:       NAME user
DELETE FROM user;

-- CHECK: DELETE_STMT_SYNTAX
-- CHECK:   CTE_RECURSIVE false
-- CHECK:   TABLE
-- CHECK:     TABLE_NAME
-- CHECK:       SCHEMA main
-- CHECK:       NAME user
-- CHECK:   WHERE_EXPR
-- CHECK:     INFIX
-- CHECK:       LHS
-- CHECK:         COLUMN
-- CHECK:           COLUMN id
-- CHECK:       OPERATOR =
-- CHECK:       RHS
-- CHECK:         BIND_PARAMETER ?
DELETE FROM user WHERE id = ?;

-- CHECK: DELETE_STMT_SYNTAX
-- CHECK:   CTE_RECURSIVE false
-- CHECK:   TABLE
-- CHECK:     TABLE_NAME
-- CHECK:       SCHEMA main
-- CHECK:       NAME user
-- CHECK:   WHERE_EXPR
-- CHECK:     INFIX
-- CHECK:       LHS
-- CHECK:         COLUMN
-- CHECK:           COLUMN id
-- CHECK:       OPERATOR =
-- CHECK:       RHS
-- CHECK:         BIND_PARAMETER ?
-- CHECK:   RETURNING_CLAUSE
-- CHECK:     VALUES
-- CHECK:       VALUE all
DELETE FROM user WHERE id = ? RETURNING *;
