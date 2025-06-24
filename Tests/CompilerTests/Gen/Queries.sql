selectUsers:
SELECT * FROM user;

selectUserById:
SELECT * FROM user WHERE id = ?;

selectUserByIds:
SELECT * FROM user WHERE id IN ?;

selectUserByName:
SELECT * FROM user WHERE fullName LIKE ?;

selectUserWithManyInputs:
SELECT *, 1 AS favoriteNumber FROM user WHERE id = ? AND firstName = ?;
