CREATE TABLE user (
    id INTEGER PRIMARY KEY,
    name TEXT
);

CREATE TABLE employee (
    companyId INTEGER,
    userId INTEGER NOT NULL REFERENCES user(id),
    PRIMARY KEY(companyId, userId)
);

CREATE TABLE noPk (value INTEGER);

-- CHECK: SINGLE
SELECT * FROM user WHERE id = 1;

-- CHECK: MANY
SELECT * FROM user;

-- CHECK: SINGLE
SELECT * FROM user LIMIT 1;

-- CHECK: SINGLE
SELECT * FROM user LIMIT 1;

-- CHECK: MANY
SELECT * FROM employee WHERE companyId = 1;

-- CHECK: SINGLE
SELECT * FROM employee WHERE companyId = 1 AND userId = 1;

-- CHECK: MANY
SELECT * FROM employee WHERE companyId = 1 OR userId = 1;

-- CHECK: MANY
SELECT * FROM noPk WHERE value = ?;
