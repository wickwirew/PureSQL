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

-- CHECK: IN id: INTEGER
-- CHECK: OUT id: INTEGER
-- CHECK: OUT fullName: TEXT
-- CHECK: OUT name: TEXT?
SELECT user.id, fullName, pet.name FROM user
JOIN pet ON user.id = pet.ownerId
WHERE user.id = ?;

-- CHECK: OUT id: INTEGER
-- CHECK: OUT petName: TEXT
-- CHECK: ERROR 'id' is ambigious in the current context
SELECT id, pet.name AS petName FROM user
INNER JOIN pet ON user.id = pet.ownerId;
