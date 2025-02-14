
-- CHECK: QUERY_DEFINITION
-- CHECK:   NAME fetchUser
-- CHECK:   STATEMENT
-- CHECK:   ...
DEFINE QUERY fetchUser AS
SELECT * FROM user WHERE id = ?;

-- CHECK: QUERY_DEFINITION
-- CHECK:   NAME insertUser
-- CHECK:   STATEMENT
-- CHECK:   ...
DEFINE QUERY insertUser AS
INSERT INTO user (id, name) VALUES (1, 'Joe');
