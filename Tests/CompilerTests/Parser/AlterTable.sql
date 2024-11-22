-- Renames

-- CHECK: ALTER_TABLE_STATEMENT
-- CHECK:   NAME user
-- CHECK:   KIND
-- CHECK:     RENAME coolUser
ALTER TABLE user RENAME TO coolUser;

-- CHECK: ALTER_TABLE_STATEMENT
-- CHECK:   NAME user
-- CHECK:   KIND
-- CHECK:     RENAME_COLUMN
-- CHECK:       firstN
-- CHECK:       firstName
ALTER TABLE user RENAME COLUMN firstN TO firstName;

-- CHECK: ALTER_TABLE_STATEMENT
-- CHECK:   NAME user
-- CHECK:   KIND
-- CHECK:     RENAME_COLUMN
-- CHECK:       firstN
-- CHECK:       firstName
ALTER TABLE user RENAME firstN TO firstName;

-- Add Columns

-- CHECK: ALTER_TABLE_STATEMENT
-- CHECK:   NAME user
-- CHECK:   KIND
-- CHECK:     ADD_COLUMN
-- CHECK:       NAME lastName
-- CHECK:       TYPE TEXT
ALTER TABLE user ADD COLUMN lastName TEXT;

-- CHECK: ALTER_TABLE_STATEMENT
-- CHECK:   NAME user
-- CHECK:   KIND
-- CHECK:     ADD_COLUMN
-- CHECK:       NAME lastName
-- CHECK:       TYPE TEXT
ALTER TABLE user ADD lastName TEXT;

-- Drop Columns

-- CHECK: ALTER_TABLE_STATEMENT
-- CHECK:   NAME user
-- CHECK:   KIND
-- CHECK:     DROP_COLUMN age
ALTER TABLE user DROP COLUMN age;

-- CHECK: ALTER_TABLE_STATEMENT
-- CHECK:   NAME user
-- CHECK:   KIND
-- CHECK:     DROP_COLUMN age
ALTER TABLE user DROP age;
