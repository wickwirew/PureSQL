CREATE TABLE user (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    firstName TEXT NOT NULL,
    lastName TEXT NOT NULL,
    preference INTEGER AS Bool,
    favoriteNumber INTEGER,
    randomValue ANY,
    bornOn STRING AS Date USING CustomDate NOT NULL,
    fullName TEXT NOT NULL GENERATED ALWAYS AS (firstName || ' ' || lastName)
);

CREATE TABLE interest (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    value TEXT NOT NULL,
    userId TEXT REFERENCES user(id)
);
