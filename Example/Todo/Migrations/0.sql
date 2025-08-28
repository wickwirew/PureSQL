CREATE TABLE todo (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL,
    created INTEGER AS Date NOT NULL DEFAULT (unixepoch()),
    completed INTEGER AS Date,
    isCompleted INTEGER AS Bool NOT NULL GENERATED ALWAYS AS (completed IS NOT NULL)
);
