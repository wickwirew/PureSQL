
-- CHECK: QUERY_DEFINITION_STMT_SYNTAX
-- CHECK:   NAME fetchUser
-- CHECK:   STATEMENT
-- CHECK:   ...
fetchUser:
SELECT * FROM user WHERE id = ?;

-- CHECK: QUERY_DEFINITION_STMT_SYNTAX
-- CHECK:   NAME insertUser
-- CHECK:   STATEMENT
-- CHECK:   ...
insertUser:
INSERT INTO user (id, name) VALUES (1, 'Joe');

-- CHECK: QUERY_DEFINITION_STMT_SYNTAX
-- CHECK:   NAME fetchUser
-- CHECK:   OUTPUT FetchedUser
-- CHECK:   STATEMENT
-- CHECK:   ...
fetchUser(output: FetchedUser):
SELECT * FROM user WHERE id = ?;

-- CHECK: QUERY_DEFINITION_STMT_SYNTAX
-- CHECK:   NAME fetchUser
-- CHECK:   INPUT TheBestInput
-- CHECK:   OUTPUT FetchedUser
-- CHECK:   STATEMENT
-- CHECK:   ...
fetchUser(input: TheBestInput, output: FetchedUser):
SELECT * FROM user WHERE id = ?;
