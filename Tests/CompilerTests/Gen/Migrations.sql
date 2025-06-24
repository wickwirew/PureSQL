CREATE TABLE user (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    firstName TEXT NOT NULL,
    lastName TEXT NOT NULL,
    fullName TEXT NOT NULL GENERATED ALWAYS AS (firstName || ' ' || lastName)
);
