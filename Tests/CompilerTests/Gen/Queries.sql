insertUser:
INSERT INTO user VALUES (?, ?, ?, ?, ?, ?, ?);

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

selectWithInterest:
SELECT user.*, interest.* FROM user INNER JOIN interest ON user.id = interest.userId;

selectWithOptionalInterest:
SELECT user.*, interest.* FROM user LEFT OUTER JOIN interest ON user.id = interest.userId;
