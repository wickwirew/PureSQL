-- CHECK: TABLE_CONSTRAINT_SYNTAX
-- CHECK:   NAME theName
-- CHECK:   KIND
-- CHECK:     PRIMARY_KEY
-- CHECK:         INDEXED_COLUMN_SYNTAX
-- CHECK:           EXPR
-- CHECK:             COLUMN
-- CHECK:               COLUMN id
-- CHECK:       CONFICT_CLAUSE_SYNTAX none
CONSTRAINT theName PRIMARY KEY (id);

-- CHECK: TABLE_CONSTRAINT_SYNTAX
-- CHECK:   NAME theName
-- CHECK:   KIND
-- CHECK:     PRIMARY_KEY
-- CHECK:         INDEXED_COLUMN_SYNTAX
-- CHECK:           EXPR
-- CHECK:             COLUMN
-- CHECK:               COLUMN id
-- CHECK:         INDEXED_COLUMN_SYNTAX
-- CHECK:           EXPR
-- CHECK:             COLUMN
-- CHECK:               COLUMN otherId
-- CHECK:       CONFICT_CLAUSE_SYNTAX none
CONSTRAINT theName PRIMARY KEY (id, otherId);

-- CHECK: TABLE_CONSTRAINT_SYNTAX
-- CHECK:   KIND
-- CHECK:     PRIMARY_KEY
-- CHECK:         INDEXED_COLUMN_SYNTAX
-- CHECK:           EXPR
-- CHECK:             COLUMN
-- CHECK:               COLUMN id
-- CHECK:       CONFICT_CLAUSE_SYNTAX ignore
PRIMARY KEY (id) ON CONFLICT IGNORE;

-- CHECK: TABLE_CONSTRAINT_SYNTAX
-- CHECK:   KIND
-- CHECK:     PRIMARY_KEY
-- CHECK:         INDEXED_COLUMN_SYNTAX
-- CHECK:           EXPR
-- CHECK:             COLUMN
-- CHECK:               COLUMN theColumn
-- CHECK:       CONFICT_CLAUSE_SYNTAX none
UNIQUE (theColumn);

-- CHECK: TABLE_CONSTRAINT_SYNTAX
-- CHECK:   KIND
-- CHECK:     PRIMARY_KEY
-- CHECK:         INDEXED_COLUMN_SYNTAX
-- CHECK:           EXPR
-- CHECK:             COLUMN
-- CHECK:               COLUMN theColumn
-- CHECK:         INDEXED_COLUMN_SYNTAX
-- CHECK:           EXPR
-- CHECK:             COLUMN
-- CHECK:               COLUMN otherColumn
-- CHECK:       CONFICT_CLAUSE_SYNTAX replace
UNIQUE (theColumn, otherColumn) ON CONFLICT REPLACE;

-- CHECK: TABLE_CONSTRAINT_SYNTAX
-- CHECK:   KIND
-- CHECK:     CHECK
-- CHECK:       LITERAL 1.0
CHECK (1);

-- CHECK: TABLE_CONSTRAINT_SYNTAX
-- CHECK:   KIND
-- CHECK:     FOREIGN_KEY
-- CHECK:         parentId
-- CHECK:         FOREIGN_TABLE otherTable
-- CHECK:         FOREIGN_COLUMNS
-- CHECK:           id
FOREIGN KEY (parentId) REFERENCES otherTable(id);

-- CHECK: TABLE_CONSTRAINT_SYNTAX
-- CHECK:   KIND
-- CHECK:     FOREIGN_KEY
-- CHECK:         parentId
-- CHECK:         otherId
-- CHECK:         FOREIGN_TABLE otherTable
-- CHECK:         FOREIGN_COLUMNS
-- CHECK:           id
-- CHECK:           otherId
FOREIGN KEY (parentId, otherId) REFERENCES otherTable(id, otherId);
