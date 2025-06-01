CREATE TABLE foo (bar INTEGER);
CREATE TABLE baz (qux INTEGER);

CREATE TRIGGER fooUpdate
AFTER UPDATE ON foo
BEGIN
INSERT INTO baz (qux) VALUES (1);
END;

-- CHECK-ERROR: Trigger with name already exists
CREATE TRIGGER fooUpdate
AFTER UPDATE ON foo
BEGIN
INSERT INTO baz (qux) VALUES (1);
END;

-- CHECK-ERROR: Trigger with name does not exist
DROP TRIGGER doesNotExist;

DROP TRIGGER IF EXISTS doesNotExistButItDoesntMatter;

-- CHECK-ERROR: Table referenced in statements of trigger 'main.fooUpdate'
DROP TABLE baz;

DROP TABLE foo;

-- CHECK-ERROR: Trigger with name does not exist
DROP TRIGGER fooUpdate;
