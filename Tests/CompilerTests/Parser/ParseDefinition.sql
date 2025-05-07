
-- CHECK: QUERY_DEFINITION_STMT_SYNTAX
-- CHECK:   NAME fetchUser
-- CHECK:   STATEMENT
-- CHECK:   ...
DEFINE QUERY fetchUser AS
SELECT * FROM user WHERE id = ?;

-- CHECK: QUERY_DEFINITION_STMT_SYNTAX
-- CHECK:   NAME insertUser
-- CHECK:   STATEMENT
-- CHECK:   ...
DEFINE QUERY insertUser AS
INSERT INTO user (id, name) VALUES (1, 'Joe');

-- CHECK: QUERY_DEFINITION_STMT_SYNTAX
-- CHECK:   NAME fetchUser
-- CHECK:   OUTPUT FetchedUser
-- CHECK:   STATEMENT
-- CHECK:   ...
DEFINE QUERY fetchUser(output: FetchedUser) AS
SELECT * FROM user WHERE id = ?;

-- CHECK: QUERY_DEFINITION_STMT_SYNTAX
-- CHECK:   NAME fetchUser
-- CHECK:   INPUT TheBestInput
-- CHECK:   OUTPUT FetchedUser
-- CHECK:   STATEMENT
-- CHECK:   ...
DEFINE QUERY fetchUser(input: TheBestInput, output: FetchedUser) AS
SELECT * FROM user WHERE id = ?;
