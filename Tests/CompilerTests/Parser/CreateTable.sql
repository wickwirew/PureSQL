-- CHECK: CREATE_TABLE_STMT
-- CHECK:   NAME user
-- CHECK:   IS_TEMPORARY false
-- CHECK:   ONLY_IF_EXISTS false
-- CHECK:   KIND
-- CHECK:     COLUMNS
-- CHECK:         KEY id
-- CHECK:         VALUE
-- CHECK:           NAME id
-- CHECK:           TYPE INT
-- CHECK:         KEY name
-- CHECK:         VALUE
-- CHECK:           NAME name
-- CHECK:           TYPE TEXT
-- CHECK:   OPTIONS []
CREATE TABLE user (id INT, name TEXT);

-- CHECK: CREATE_TABLE_STMT
-- CHECK:   NAME user
-- CHECK:   IS_TEMPORARY false
-- CHECK:   ONLY_IF_EXISTS false
-- CHECK:   KIND
-- CHECK:     COLUMNS
-- CHECK:         KEY id
-- CHECK:         VALUE
-- CHECK:           NAME id
-- CHECK:           TYPE INT
-- CHECK:           CONSTRAINTS
-- CHECK:             COLUMN_CONSTRAINT
-- CHECK:               KIND
-- CHECK:                 PRIMARY_KEY
-- CHECK:                   ORDER asc
-- CHECK:                   CONFICT_CLAUSE none
-- CHECK:                   AUTOINCREMENT false
-- CHECK:         KEY name
-- CHECK:         VALUE
-- CHECK:           NAME name
-- CHECK:           TYPE TEXT
-- CHECK:   OPTIONS []
CREATE TABLE user (id INT PRIMARY KEY, name TEXT);

-- CHECK: CREATE_TABLE_STMT
-- CHECK:   NAME user
-- CHECK:   IS_TEMPORARY false
-- CHECK:   ONLY_IF_EXISTS false
-- CHECK:   KIND
-- CHECK:     COLUMNS
-- CHECK:         KEY id
-- CHECK:         VALUE
-- CHECK:           NAME id
-- CHECK:           TYPE INT
-- CHECK:           CONSTRAINTS
-- CHECK:             COLUMN_CONSTRAINT
-- CHECK:               KIND
-- CHECK:                 PRIMARY_KEY
-- CHECK:                   ORDER asc
-- CHECK:                   CONFICT_CLAUSE replace
-- CHECK:                   AUTOINCREMENT false
-- CHECK:         KEY name
-- CHECK:         VALUE
-- CHECK:           NAME name
-- CHECK:           TYPE TEXT
-- CHECK:   OPTIONS []
CREATE TABLE user (
    id INT PRIMARY KEY ON CONFLICT REPLACE,
    name TEXT
);

-- CHECK: CREATE_TABLE_STMT
-- CHECK:   NAME user
-- CHECK:   IS_TEMPORARY false
-- CHECK:   ONLY_IF_EXISTS false
-- CHECK:   KIND
-- CHECK:     COLUMNS
-- CHECK:         KEY id
-- CHECK:         VALUE
-- CHECK:           NAME id
-- CHECK:           TYPE INT
-- CHECK:           CONSTRAINTS
-- CHECK:             COLUMN_CONSTRAINT
-- CHECK:               KIND
-- CHECK:                 PRIMARY_KEY
-- CHECK:                   ORDER asc
-- CHECK:                   CONFICT_CLAUSE replace
-- CHECK:                   AUTOINCREMENT true
-- CHECK:         KEY name
-- CHECK:         VALUE
-- CHECK:           NAME name
-- CHECK:           TYPE TEXT
-- CHECK:   OPTIONS []
CREATE TABLE user (
    id INT PRIMARY KEY ASC ON CONFLICT REPLACE AUTOINCREMENT,
    name TEXT
);

-- CHECK: CREATE_TABLE_STMT
-- CHECK:   NAME user
-- CHECK:   IS_TEMPORARY false
-- CHECK:   ONLY_IF_EXISTS false
-- CHECK:   KIND
-- CHECK:     COLUMNS
-- CHECK:         KEY id
-- CHECK:         VALUE
-- CHECK:           NAME id
-- CHECK:           TYPE INTEGER
-- CHECK:           CONSTRAINTS
-- CHECK:             COLUMN_CONSTRAINT
-- CHECK:               KIND
-- CHECK:                 PRIMARY_KEY
-- CHECK:                   ORDER desc
-- CHECK:                   CONFICT_CLAUSE replace
-- CHECK:                   AUTOINCREMENT true
-- CHECK:             COLUMN_CONSTRAINT
-- CHECK:               KIND
-- CHECK:                 NOT_NULL none
-- CHECK:             COLUMN_CONSTRAINT
-- CHECK:               KIND
-- CHECK:                 UNIQUE ignore
-- CHECK:             COLUMN_CONSTRAINT
-- CHECK:               KIND
-- CHECK:                 DEFAULT
-- CHECK:                   LITERAL 100.0
-- CHECK:         KEY name
-- CHECK:         VALUE
-- CHECK:           NAME name
-- CHECK:           TYPE TEXT
-- CHECK:   OPTIONS []
CREATE TABLE user (
    id INTEGER PRIMARY KEY DESC ON CONFLICT REPLACE AUTOINCREMENT NOT NULL UNIQUE ON CONFLICT IGNORE DEFAULT 100,
    name TEXT
);

-- CHECK: CREATE_TABLE_STMT
-- CHECK:   NAME user
-- CHECK:   IS_TEMPORARY false
-- CHECK:   ONLY_IF_EXISTS false
-- CHECK:   KIND
-- CHECK:     COLUMNS
-- CHECK:         KEY id
-- CHECK:         VALUE
-- CHECK:           NAME id
-- CHECK:           TYPE INT
-- CHECK:           CONSTRAINTS
-- CHECK:             COLUMN_CONSTRAINT
-- CHECK:               KIND
-- CHECK:                 PRIMARY_KEY
-- CHECK:                   ORDER asc
-- CHECK:                   CONFICT_CLAUSE replace
-- CHECK:                   AUTOINCREMENT true
-- CHECK:         KEY name
-- CHECK:         VALUE
-- CHECK:           NAME name
-- CHECK:           TYPE TEXT
-- CHECK:           CONSTRAINTS
-- CHECK:             COLUMN_CONSTRAINT
-- CHECK:               KIND
-- CHECK:                 UNIQUE ignore
-- CHECK:             COLUMN_CONSTRAINT
-- CHECK:               KIND
-- CHECK:                 DEFAULT
-- CHECK:                   LITERAL 'Joe'
-- CHECK:         KEY age
-- CHECK:         VALUE
-- CHECK:           NAME age
-- CHECK:           TYPE INT
-- CHECK:           CONSTRAINTS
-- CHECK:             COLUMN_CONSTRAINT
-- CHECK:               KIND
-- CHECK:                 NOT_NULL none
-- CHECK:         KEY agePlus1
-- CHECK:         VALUE
-- CHECK:           NAME agePlus1
-- CHECK:           TYPE INT
-- CHECK:           CONSTRAINTS
-- CHECK:             COLUMN_CONSTRAINT
-- CHECK:               KIND
-- CHECK:                 GENERATED
-- CHECK:                     BIND_PARAMETER ?1
-- CHECK:                   virtual
-- CHECK:         KEY countryId
-- CHECK:         VALUE
-- CHECK:           NAME countryId
-- CHECK:           TYPE INT
-- CHECK:           CONSTRAINTS
-- CHECK:             COLUMN_CONSTRAINT
-- CHECK:               KIND
-- CHECK:                 FOREIGN_KEY
-- CHECK:                   FOREIGN_TABLE country
-- CHECK:                   FOREIGN_COLUMNS
-- CHECK:                     id
-- CHECK:                   ACTIONS
-- CHECK:                     ACTION
-- CHECK:                       ON_DO
-- CHECK:                         ON delete
-- CHECK:                         DO cascade
-- CHECK:   OPTIONS []
CREATE TABLE user (
    id INT PRIMARY KEY ASC ON CONFLICT REPLACE AUTOINCREMENT,
    name TEXT UNIQUE ON CONFLICT IGNORE DEFAULT 'Joe',
    age INT NOT NULL,
    agePlus1 INT GENERATED ALWAYS AS (?) VIRTUAL,
    countryId INT REFERENCES country(id) ON DELETE CASCADE
);

-- CHECK: CREATE_TABLE_STMT
-- CHECK:   NAME user
-- CHECK:   IS_TEMPORARY false
-- CHECK:   ONLY_IF_EXISTS false
-- CHECK:   KIND
-- CHECK:     COLUMNS
-- CHECK:         KEY id
-- CHECK:         VALUE
-- CHECK:           NAME id
-- CHECK:           TYPE INT
-- CHECK:           CONSTRAINTS
-- CHECK:             COLUMN_CONSTRAINT
-- CHECK:               KIND
-- CHECK:                 PRIMARY_KEY
-- CHECK:                   ORDER asc
-- CHECK:                   CONFICT_CLAUSE none
-- CHECK:                   AUTOINCREMENT false
-- CHECK:         KEY name
-- CHECK:         VALUE
-- CHECK:           NAME name
-- CHECK:           TYPE TEXT
-- CHECK:           CONSTRAINTS
-- CHECK:             COLUMN_CONSTRAINT
-- CHECK:               NAME name_unique
-- CHECK:               KIND
-- CHECK:                 UNIQUE ignore
-- CHECK:   OPTIONS []
CREATE TABLE user (
    id INT PRIMARY KEY,
    name TEXT CONSTRAINT name_unique UNIQUE ON CONFLICT IGNORE
);
