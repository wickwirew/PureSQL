-- CHECK:   COLUMN_EXPR_SYNTAX
-- CHECK:     COLUMN foo
foo;

-- CHECK:   COLUMN_EXPR_SYNTAX
-- CHECK:     TABLE foo
-- CHECK:     COLUMN bar
foo.bar;

-- CHECK:   COLUMN_EXPR_SYNTAX
-- CHECK:     SCHEMA foo
-- CHECK:     TABLE bar
-- CHECK:     COLUMN baz
foo.bar.baz;

-- CHECK:   COLUMN_EXPR_SYNTAX
-- CHECK:     SCHEMA foo
-- CHECK:     TABLE bar
-- CHECK:     COLUMN *
foo.bar.*;

-- CHECK:   COLUMN_EXPR_SYNTAX
-- CHECK:     TABLE bar
-- CHECK:     COLUMN *
bar.*;

-- CHECK:   COLUMN_EXPR_SYNTAX
-- CHECK:     COLUMN *
*;

-- CHECK:   1.0
1.0;

-- CHECK:   255.0
255.0;

-- CHECK:   1.0
1.0;

-- CHECK:   'foo'
'foo';

-- CHECK:   NULL
NULL;

-- CHECK:   TRUE
TRUE;

-- CHECK:   FALSE
FALSE;

-- CHECK:   CURRENT_TIME
CURRENT_TIME;

-- CHECK:   CURRENT_DATE
CURRENT_DATE;

-- CHECK:   CURRENT_TIMESTAMP
CURRENT_TIMESTAMP;

-- CHECK:   PREFIX_EXPR_SYNTAX
-- CHECK:     OPERATOR ~
-- CHECK:     RHS 1.0
~1;

-- CHECK:   PREFIX_EXPR_SYNTAX
-- CHECK:     OPERATOR +
-- CHECK:     RHS 1.0
+1;

-- CHECK:   PREFIX_EXPR_SYNTAX
-- CHECK:     OPERATOR -
-- CHECK:     RHS 1.0
-1;

-- CHECK:   INFIX_EXPR_SYNTAX
-- CHECK:     LHS 1.0
-- CHECK:     OPERATOR +
-- CHECK:     RHS 2.0
1 + 2;

-- CHECK:   INFIX_EXPR_SYNTAX
-- CHECK:     LHS
-- CHECK:         LHS 1.0
-- CHECK:         OPERATOR +
-- CHECK:         RHS 2.0
-- CHECK:     OPERATOR +
-- CHECK:     RHS 3.0
1 + 2 + 3;

-- CHECK:   INFIX_EXPR_SYNTAX
-- CHECK:     LHS
-- CHECK:         LHS 1.0
-- CHECK:         OPERATOR *
-- CHECK:         RHS 2.0
-- CHECK:     OPERATOR +
-- CHECK:     RHS 3.0
1 * 2 + 3;

-- CHECK:   INFIX_EXPR_SYNTAX
-- CHECK:     LHS 1.0
-- CHECK:     OPERATOR +
-- CHECK:     RHS
-- CHECK:         LHS 2.0
-- CHECK:         OPERATOR *
-- CHECK:         RHS 3.0
1 + 2 * 3;

-- CHECK:   INFIX_EXPR_SYNTAX
-- CHECK:     LHS 1.0
-- CHECK:     OPERATOR +
-- CHECK:     RHS
-- CHECK:         LHS 2.0
-- CHECK:         OPERATOR /
-- CHECK:         RHS 3.0
1 + 2 / 3;

-- CHECK:   INFIX_EXPR_SYNTAX
-- CHECK:     LHS 1.0
-- CHECK:     OPERATOR +
-- CHECK:     RHS
-- CHECK:         OPERATOR -
-- CHECK:         RHS 2.0
1 +-2;

-- CHECK:   GROUPED_EXPR_SYNTAX
-- CHECK:     EXPRS
-- CHECK:         INFIX_EXPR_SYNTAX
-- CHECK:           LHS 1.0
-- CHECK:           OPERATOR +
-- CHECK:           RHS 2.0
(1 + 2);

-- CHECK:   INFIX_EXPR_SYNTAX
-- CHECK:     LHS
-- CHECK:         EXPRS
-- CHECK:             INFIX_EXPR_SYNTAX
-- CHECK:               LHS 1.0
-- CHECK:               OPERATOR +
-- CHECK:               RHS 2.0
-- CHECK:     OPERATOR *
-- CHECK:     RHS 3.0
(1 + 2) * 3;

-- CHECK:   FUNCTION_EXPR_SYNTAX
-- CHECK:     NAME foo
-- CHECK:     ARGS
-- CHECK:       1.0
foo(1);

-- CHECK:   FUNCTION_EXPR_SYNTAX
-- CHECK:     NAME foo
-- CHECK:     ARGS
-- CHECK:         1.0
-- CHECK:         INFIX_EXPR_SYNTAX
-- CHECK:           LHS 2.0
-- CHECK:           OPERATOR +
-- CHECK:           RHS 3.0
foo(1, 2 + 3);

-- CHECK:   FUNCTION_EXPR_SYNTAX
-- CHECK:     NAME foo
-- CHECK:     ARGS
-- CHECK:         COLUMN_EXPR_SYNTAX
-- CHECK:           TABLE bar
-- CHECK:           COLUMN baz
foo(bar.baz);

-- CHECK:   CAST_EXPR_SYNTAX
-- CHECK:     EXPR
-- CHECK:       COLUMN foo
-- CHECK:     TY TEXT
CAST(foo AS TEXT);

-- CHECK:   POSTFIX_EXPR_SYNTAX
-- CHECK:     LHS 'foo'
-- CHECK:     OPERATOR COLLATE NOCASE
'foo' COLLATE NOCASE;

-- CHECK:   INFIX_EXPR_SYNTAX
-- CHECK:     LHS
-- CHECK:       COLUMN foo
-- CHECK:     OPERATOR NOT LIKE
-- CHECK:     RHS 'bar'
foo NOT LIKE 'bar';

-- CHECK:   INFIX_EXPR_SYNTAX
-- CHECK:     LHS
-- CHECK:       COLUMN foo
-- CHECK:     OPERATOR LIKE
-- CHECK:     RHS 'bar'
foo LIKE 'bar';

-- CHECK:   INFIX_EXPR_SYNTAX
-- CHECK:     LHS
-- CHECK:       COLUMN foo
-- CHECK:     OPERATOR LIKE
-- CHECK:     RHS
-- CHECK:         LHS 'bar'
-- CHECK:         OPERATOR ESCAPE
-- CHECK:         RHS '\\'
foo LIKE 'bar' ESCAPE '\\';

-- CHECK:   INFIX_EXPR_SYNTAX
-- CHECK:     LHS
-- CHECK:       COLUMN foo
-- CHECK:     OPERATOR NOT GLOB
-- CHECK:     RHS 'bar'
foo NOT GLOB 'bar';

-- CHECK:   INFIX_EXPR_SYNTAX
-- CHECK:     LHS
-- CHECK:       COLUMN foo
-- CHECK:     OPERATOR GLOB
-- CHECK:     RHS 'bar'
foo GLOB 'bar';

-- CHECK:   INFIX_EXPR_SYNTAX
-- CHECK:     LHS
-- CHECK:       COLUMN foo
-- CHECK:     OPERATOR NOT REGEXP
-- CHECK:     RHS 'bar'
foo NOT REGEXP 'bar';

-- CHECK:   INFIX_EXPR_SYNTAX
-- CHECK:     LHS
-- CHECK:       COLUMN foo
-- CHECK:     OPERATOR REGEXP
-- CHECK:     RHS 'bar'
foo REGEXP 'bar';

-- CHECK:   INFIX_EXPR_SYNTAX
-- CHECK:     LHS
-- CHECK:       COLUMN foo
-- CHECK:     OPERATOR NOT MATCH
-- CHECK:     RHS 'bar'
foo NOT MATCH 'bar';

-- CHECK:   INFIX_EXPR_SYNTAX
-- CHECK:     LHS
-- CHECK:       COLUMN foo
-- CHECK:     OPERATOR MATCH
-- CHECK:     RHS 'bar'
foo MATCH 'bar';

-- CHECK:   POSTFIX_EXPR_SYNTAX
-- CHECK:     LHS
-- CHECK:       COLUMN foo
-- CHECK:     OPERATOR ISNULL
foo ISNULL;

-- CHECK:   POSTFIX_EXPR_SYNTAX
-- CHECK:     LHS
-- CHECK:       COLUMN foo
-- CHECK:     OPERATOR NOTNULL
foo NOTNULL;

-- CHECK:   POSTFIX_EXPR_SYNTAX
-- CHECK:     LHS
-- CHECK:       COLUMN foo
-- CHECK:     OPERATOR NOT NULL
foo NOT NULL;

-- CHECK:   INFIX_EXPR_SYNTAX
-- CHECK:     LHS
-- CHECK:       COLUMN foo
-- CHECK:     OPERATOR IS DISTINCT FROM
-- CHECK:     RHS 1.0
foo IS DISTINCT FROM 1;

-- CHECK:   INFIX_EXPR_SYNTAX
-- CHECK:     LHS
-- CHECK:       COLUMN foo
-- CHECK:     OPERATOR IS NOT DISTINCT FROM
-- CHECK:     RHS 1.0
foo IS NOT DISTINCT FROM 1;

-- CHECK:   INFIX_EXPR_SYNTAX
-- CHECK:     LHS
-- CHECK:       COLUMN foo
-- CHECK:     OPERATOR IS NOT
-- CHECK:     RHS 1.0
foo IS NOT 1;

-- CHECK:   INFIX_EXPR_SYNTAX
-- CHECK:     LHS
-- CHECK:       COLUMN foo
-- CHECK:     OPERATOR IS
-- CHECK:     RHS 1.0
foo IS 1;

-- CHECK:   BETWEEN_EXPR_SYNTAX
-- CHECK:     NOT false
-- CHECK:     VALUE
-- CHECK:       COLUMN foo
-- CHECK:     LOWER 1.0
-- CHECK:     UPPER 2.0
foo BETWEEN 1 AND 2;

-- CHECK:   BETWEEN_EXPR_SYNTAX
-- CHECK:     NOT false
-- CHECK:     VALUE
-- CHECK:       COLUMN foo
-- CHECK:     LOWER
-- CHECK:         LHS 1.0
-- CHECK:         OPERATOR +
-- CHECK:         RHS 2.0
-- CHECK:     UPPER
-- CHECK:         LHS 2.0
-- CHECK:         OPERATOR *
-- CHECK:         RHS 5.0
foo BETWEEN 1 + 2 AND 2 * 5;

-- CHECK:   BETWEEN_EXPR_SYNTAX
-- CHECK:     NOT true
-- CHECK:     VALUE
-- CHECK:       COLUMN foo
-- CHECK:     LOWER 1.0
-- CHECK:     UPPER 2.0
foo NOT BETWEEN 1 AND 2;


-- CHECK:   INFIX_EXPR_SYNTAX
-- CHECK:     LHS
-- CHECK:       COLUMN foo
-- CHECK:     OPERATOR IN
-- CHECK:     RHS
-- CHECK:         EXPRS
-- CHECK:             1.0
-- CHECK:             2.0
-- CHECK:             3.0
foo IN (1, 2, 3);

-- CHECK:   INFIX_EXPR_SYNTAX
-- CHECK:     LHS
-- CHECK:       COLUMN foo
-- CHECK:     OPERATOR NOT IN
-- CHECK:     RHS
-- CHECK:         EXPRS
-- CHECK:             1.0
-- CHECK:             2.0
-- CHECK:             3.0
foo NOT IN (1, 2, 3);

-- CHECK:   INFIX_EXPR_SYNTAX
-- CHECK:     LHS
-- CHECK:       COLUMN foo
-- CHECK:     OPERATOR IN
-- CHECK:     RHS
-- CHECK:         TABLE foo
-- CHECK:         NAME baz
-- CHECK:         ARGS
-- CHECK:           1.0
foo IN foo.baz(1);

-- CHECK:   INFIX_EXPR_SYNTAX
-- CHECK:     LHS
-- CHECK:       COLUMN foo
-- CHECK:     OPERATOR IN
-- CHECK:     RHS
-- CHECK:         TABLE foo
-- CHECK:         COLUMN baz
foo IN foo.baz;

-- CHECK:   CASE_WHEN_THEN_EXPR_SYNTAX
-- CHECK:     CASE
-- CHECK:       COLUMN foo
-- CHECK:     WHEN_THEN
-- CHECK:       WHEN_THEN
-- CHECK:         WHEN 1.0
-- CHECK:         THEN 'one'
-- CHECK:       WHEN_THEN
-- CHECK:         WHEN 2.0
-- CHECK:         THEN 'two'
-- CHECK:       WHEN_THEN
-- CHECK:         WHEN 3.0
-- CHECK:         THEN 'three'
CASE foo WHEN 1 THEN 'one' WHEN 2 THEN 'two' WHEN 3 THEN 'three' END;

-- CHECK:   CASE_WHEN_THEN_EXPR_SYNTAX
-- CHECK:     WHEN_THEN
-- CHECK:       WHEN_THEN
-- CHECK:         WHEN 1.0
-- CHECK:         THEN 'one'
-- CHECK:       WHEN_THEN
-- CHECK:         WHEN 2.0
-- CHECK:         THEN 'two'
-- CHECK:       WHEN_THEN
-- CHECK:         WHEN 3.0
-- CHECK:         THEN 'three'
CASE WHEN 1 THEN 'one' WHEN 2 THEN 'two' WHEN 3 THEN 'three' END;

-- CHECK:   CASE_WHEN_THEN_EXPR_SYNTAX
-- CHECK:     WHEN_THEN
-- CHECK:       WHEN_THEN
-- CHECK:         WHEN 1.0
-- CHECK:         THEN 'one'
-- CHECK:       WHEN_THEN
-- CHECK:         WHEN 2.0
-- CHECK:         THEN 'two'
-- CHECK:       WHEN_THEN
-- CHECK:         WHEN 3.0
-- CHECK:         THEN 'three'
-- CHECK:     ELSE 'meh'
CASE WHEN 1 THEN 'one' WHEN 2 THEN 'two' WHEN 3 THEN 'three' ELSE 'meh' END;

-- CHECK:   INFIX_EXPR_SYNTAX
-- CHECK:     LHS
-- CHECK:         COLUMN foo
-- CHECK:     OPERATOR IS
-- CHECK:     RHS NULL
foo IS NULL;

-- CHECK:   INFIX_EXPR_SYNTAX
-- CHECK:     LHS
-- CHECK:         COLUMN foo
-- CHECK:     OPERATOR IS DISTINCT FROM
-- CHECK:     RHS NULL
foo IS DISTINCT FROM NULL;

-- CHECK:   BETWEEN_EXPR_SYNTAX
-- CHECK:     NOT false
-- CHECK:     VALUE
-- CHECK:         COLUMN foo
-- CHECK:     LOWER 1.0
-- CHECK:     UPPER 2.0
foo BETWEEN 1 AND 2;

-- CHECK:   BETWEEN_EXPR_SYNTAX
-- CHECK:     NOT false
-- CHECK:     VALUE
-- CHECK:         COLUMN foo
-- CHECK:     LOWER
-- CHECK:         LHS 1.0
-- CHECK:         OPERATOR +
-- CHECK:         RHS 2.0
-- CHECK:     UPPER
-- CHECK:         LHS 2.0
-- CHECK:         OPERATOR *
-- CHECK:         RHS 5.0
foo BETWEEN 1 + 2 AND 2 * 5;

-- CHECK:   BETWEEN_EXPR_SYNTAX
-- CHECK:     NOT true
-- CHECK:     VALUE
-- CHECK:         COLUMN foo
-- CHECK:     LOWER 1.0
-- CHECK:     UPPER 2.0
foo NOT BETWEEN 1 AND 2;

-- CHECK:   EXISTS_EXPR_SYNTAX
-- CHECK:     NOT false
-- CHECK:     SELECT
-- CHECK:       ...
EXISTS(SELECT * FROM foo);

-- CHECK:   EXISTS
-- CHECK:     NOT true
-- CHECK:     SELECT
-- CHECK:       ...
NOT EXISTS(SELECT * FROM foo);
