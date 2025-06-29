CREATE TABLE user (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    firstName TEXT NOT NULL,
    lastName TEXT NOT NULL,
    preference INTEGER AS Bool,
    favoriteNumber INTEGER,
    randomValue ANY,
    bornOn TEXT AS Date USING CustomDate,
    fullName TEXT NOT NULL GENERATED ALWAYS AS (firstName || ' ' || lastName)
);

CREATE TABLE interest (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    value TEXT NOT NULL,
    userId INTEGER REFERENCES user(id)
);
