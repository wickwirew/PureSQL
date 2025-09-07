CREATE TABLE foo (
    intPk INTEGER PRIMARY KEY AUTOINCREMENT,
    textNotNull TEXT NOT NULL,
    textNullable TEXT,
    dateWithAdapterNotNull INTEGER AS Date NOT NULL,
    dateWithAdapterNullable INTEGER AS Date,
    dateWithCustomAdapter TEXT AS Date USING CustomDate,
    generatedColumn TEXT NOT NULL GENERATED ALWAYS AS ('a-good-prefix ' || textNotNull)
);

CREATE TABLE bar (
    intPk INTEGER PRIMARY KEY,
    barNotNullText TEXT NOT NULL
);
