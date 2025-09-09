insertFooReturningFoo:
INSERT INTO foo
(textNotNull, textNullable, dateWithAdapterNotNull, dateWithAdapterNullable, dateWithCustomAdapter)
VALUES (?, ?, ?, ?, ?)
RETURNING *;

insertBarReturningIntPk:
INSERT INTO bar (intPk, barNotNullText) VALUES (:customNameIntPk, ?) RETURNING intPk;

insertBarReturningExtraColumn:
INSERT INTO bar VALUES (?, ?) RETURNING *, 123 AS columnAfter;

selectSingleFoo:
SELECT * FROM foo WHERE intPk = ?;

hasEmbeddedFoo:
SELECT foo.*, bar.barNotNullText AS shouldBeNullable
FROM foo
LEFT OUTER JOIN bar ON foo.intPk = bar.intPk
WHERE foo.intPk = ?;

bothColumnsShouldNotBeNullable:
SELECT foo.intPk AS f, bar.intPk AS b FROM foo
INNER JOIN bar ON foo.intPk = bar.intPk;

selectWithManyInputs:
SELECT * FROM foo WHERE intPk = ? AND textNotNull = ?;

inputIsArray:
DELETE FROM bar WHERE intPk IN ?;

inputContainsArray:
DELETE FROM bar WHERE intPk IN ? AND barNotNullText = ?;
