-- CHECK: EXPRESSION_SYNTAX
-- CHECK:   COLUMN
-- CHECK:     COLUMN foo
foo;

-- CHECK: EXPRESSION_SYNTAX
-- CHECK:   COLUMN
-- CHECK:     TABLE foo
-- CHECK:     COLUMN bar
foo.bar;

-- CHECK: EXPRESSION_SYNTAX
-- CHECK:   COLUMN
-- CHECK:     SCHEMA foo
-- CHECK:     TABLE bar
-- CHECK:     COLUMN baz
foo.bar.baz;

-- CHECK: EXPRESSION_SYNTAX
-- CHECK:   COLUMN
-- CHECK:     SCHEMA foo
-- CHECK:     TABLE bar
-- CHECK:     COLUMN *
foo.bar.*;

-- CHECK: EXPRESSION_SYNTAX
-- CHECK:   COLUMN
-- CHECK:     TABLE bar
-- CHECK:     COLUMN *
bar.*;

-- CHECK: EXPRESSION_SYNTAX
-- CHECK:   COLUMN
-- CHECK:     COLUMN *
*;

-- CHECK: EXPRESSION_SYNTAX
-- CHECK:   LITERAL 1.0
1.0;

-- CHECK: EXPRESSION_SYNTAX
-- CHECK:   LITERAL 255.0
255.0;

-- CHECK: EXPRESSION_SYNTAX
-- CHECK:   LITERAL 1.0
1.0;

-- CHECK: EXPRESSION_SYNTAX
-- CHECK:   LITERAL 'foo'
'foo';

-- CHECK: EXPRESSION_SYNTAX
-- CHECK:   LITERAL NULL
NULL;

-- CHECK: EXPRESSION_SYNTAX
-- CHECK:   LITERAL TRUE
TRUE;

-- CHECK: EXPRESSION_SYNTAX
-- CHECK:   LITERAL FALSE
FALSE;

-- CHECK: EXPRESSION_SYNTAX
-- CHECK:   LITERAL CURRENT_TIME
CURRENT_TIME;

-- CHECK: EXPRESSION_SYNTAX
-- CHECK:   LITERAL CURRENT_DATE
CURRENT_DATE;

-- CHECK: EXPRESSION_SYNTAX
-- CHECK:   LITERAL CURRENT_TIMESTAMP
CURRENT_TIMESTAMP;

-- CHECK: EXPRESSION_SYNTAX
-- CHECK:   PREFIX
-- CHECK:     OPERATOR ~
-- CHECK:     RHS
-- CHECK:       LITERAL 1.0
~1;

-- CHECK: EXPRESSION_SYNTAX
-- CHECK:   PREFIX
-- CHECK:     OPERATOR +
-- CHECK:     RHS
-- CHECK:       LITERAL 1.0
+1;

-- CHECK: EXPRESSION_SYNTAX
-- CHECK:   PREFIX
-- CHECK:     OPERATOR -
-- CHECK:     RHS
-- CHECK:       LITERAL 1.0
-1;

-- CHECK: EXPRESSION_SYNTAX
-- CHECK:   INFIX
-- CHECK:     LHS
-- CHECK:       LITERAL 1.0
-- CHECK:     OPERATOR +
-- CHECK:     RHS
-- CHECK:       LITERAL 2.0
1 + 2;

-- CHECK: EXPRESSION_SYNTAX
-- CHECK:   INFIX
-- CHECK:     LHS
-- CHECK:       INFIX
-- CHECK:         LHS
-- CHECK:           LITERAL 1.0
-- CHECK:         OPERATOR +
-- CHECK:         RHS
-- CHECK:           LITERAL 2.0
-- CHECK:     OPERATOR +
-- CHECK:     RHS
-- CHECK:       LITERAL 3.0
1 + 2 + 3;

-- CHECK: EXPRESSION_SYNTAX
-- CHECK:   INFIX
-- CHECK:     LHS
-- CHECK:       INFIX
-- CHECK:         LHS
-- CHECK:           LITERAL 1.0
-- CHECK:         OPERATOR *
-- CHECK:         RHS
-- CHECK:           LITERAL 2.0
-- CHECK:     OPERATOR +
-- CHECK:     RHS
-- CHECK:       LITERAL 3.0
1 * 2 + 3;

-- CHECK: EXPRESSION_SYNTAX
-- CHECK:   INFIX
-- CHECK:     LHS
-- CHECK:       LITERAL 1.0
-- CHECK:     OPERATOR +
-- CHECK:     RHS
-- CHECK:       INFIX
-- CHECK:         LHS
-- CHECK:           LITERAL 2.0
-- CHECK:         OPERATOR *
-- CHECK:         RHS
-- CHECK:           LITERAL 3.0
1 + 2 * 3;

-- CHECK: EXPRESSION_SYNTAX
-- CHECK:   INFIX
-- CHECK:     LHS
-- CHECK:       LITERAL 1.0
-- CHECK:     OPERATOR +
-- CHECK:     RHS
-- CHECK:       INFIX
-- CHECK:         LHS
-- CHECK:           LITERAL 2.0
-- CHECK:         OPERATOR /
-- CHECK:         RHS
-- CHECK:           LITERAL 3.0
1 + 2 / 3;

-- CHECK: EXPRESSION_SYNTAX
-- CHECK:   INFIX
-- CHECK:     LHS
-- CHECK:       LITERAL 1.0
-- CHECK:     OPERATOR +
-- CHECK:     RHS
-- CHECK:       PREFIX
-- CHECK:         OPERATOR -
-- CHECK:         RHS
-- CHECK:           LITERAL 2.0
1 +-2;

-- CHECK: EXPRESSION_SYNTAX
-- CHECK:   GROUPED
-- CHECK:     EXPRS
-- CHECK:       EXPRESSION_SYNTAX
-- CHECK:         INFIX
-- CHECK:           LHS
-- CHECK:             LITERAL 1.0
-- CHECK:           OPERATOR +
-- CHECK:           RHS
-- CHECK:             LITERAL 2.0
(1 + 2);

-- CHECK: EXPRESSION_SYNTAX
-- CHECK:   INFIX
-- CHECK:     LHS
-- CHECK:       GROUPED
-- CHECK:         EXPRS
-- CHECK:           EXPRESSION_SYNTAX
-- CHECK:             INFIX
-- CHECK:               LHS
-- CHECK:                 LITERAL 1.0
-- CHECK:               OPERATOR +
-- CHECK:               RHS
-- CHECK:                 LITERAL 2.0
-- CHECK:     OPERATOR *
-- CHECK:     RHS
-- CHECK:       LITERAL 3.0
(1 + 2) * 3;

-- CHECK: EXPRESSION_SYNTAX
-- CHECK:   FN
-- CHECK:     NAME foo
-- CHECK:     ARGS
-- CHECK:       EXPRESSION_SYNTAX
-- CHECK:         LITERAL 1.0
foo(1);

-- CHECK: EXPRESSION_SYNTAX
-- CHECK:   FN
-- CHECK:     NAME foo
-- CHECK:     ARGS
-- CHECK:       EXPRESSION_SYNTAX
-- CHECK:         LITERAL 1.0
-- CHECK:       EXPRESSION_SYNTAX
-- CHECK:         INFIX
-- CHECK:           LHS
-- CHECK:             LITERAL 2.0
-- CHECK:           OPERATOR +
-- CHECK:           RHS
-- CHECK:             LITERAL 3.0
foo(1, 2 + 3);

-- CHECK: EXPRESSION_SYNTAX
-- CHECK:   FN
-- CHECK:     NAME foo
-- CHECK:     ARGS
-- CHECK:       EXPRESSION_SYNTAX
-- CHECK:         COLUMN
-- CHECK:           TABLE bar
-- CHECK:           COLUMN baz
foo(bar.baz);

-- CHECK: EXPRESSION_SYNTAX
-- CHECK:   CAST
-- CHECK:     EXPR
-- CHECK:       COLUMN
-- CHECK:         COLUMN foo
-- CHECK:     TY TEXT
CAST(foo AS TEXT);

-- CHECK: EXPRESSION_SYNTAX
-- CHECK:   POSTFIX
-- CHECK:     LHS
-- CHECK:       LITERAL 'foo'
-- CHECK:     OPERATOR COLLATE NOCASE
'foo' COLLATE NOCASE;

-- CHECK: EXPRESSION_SYNTAX
-- CHECK:   INFIX
-- CHECK:     LHS
-- CHECK:       COLUMN
-- CHECK:         COLUMN foo
-- CHECK:     OPERATOR NOT LIKE
-- CHECK:     RHS
-- CHECK:       LITERAL 'bar'
foo NOT LIKE 'bar';

-- CHECK: EXPRESSION_SYNTAX
-- CHECK:   INFIX
-- CHECK:     LHS
-- CHECK:       COLUMN
-- CHECK:         COLUMN foo
-- CHECK:     OPERATOR LIKE
-- CHECK:     RHS
-- CHECK:       LITERAL 'bar'
foo LIKE 'bar';

-- CHECK: EXPRESSION_SYNTAX
-- CHECK:   INFIX
-- CHECK:     LHS
-- CHECK:       COLUMN
-- CHECK:         COLUMN foo
-- CHECK:     OPERATOR LIKE
-- CHECK:     RHS
-- CHECK:       INFIX
-- CHECK:         LHS
-- CHECK:           LITERAL 'bar'
-- CHECK:         OPERATOR ESCAPE
-- CHECK:         RHS
-- CHECK:           LITERAL '\\'
foo LIKE 'bar' ESCAPE '\\';

-- CHECK: EXPRESSION_SYNTAX
-- CHECK:   INFIX
-- CHECK:     LHS
-- CHECK:       COLUMN
-- CHECK:         COLUMN foo
-- CHECK:     OPERATOR NOT GLOB
-- CHECK:     RHS
-- CHECK:       LITERAL 'bar'
foo NOT GLOB 'bar';

-- CHECK: EXPRESSION_SYNTAX
-- CHECK:   INFIX
-- CHECK:     LHS
-- CHECK:       COLUMN
-- CHECK:         COLUMN foo
-- CHECK:     OPERATOR GLOB
-- CHECK:     RHS
-- CHECK:       LITERAL 'bar'
foo GLOB 'bar';

-- CHECK: EXPRESSION_SYNTAX
-- CHECK:   INFIX
-- CHECK:     LHS
-- CHECK:       COLUMN
-- CHECK:         COLUMN foo
-- CHECK:     OPERATOR NOT REGEXP
-- CHECK:     RHS
-- CHECK:       LITERAL 'bar'
foo NOT REGEXP 'bar';

-- CHECK: EXPRESSION_SYNTAX
-- CHECK:   INFIX
-- CHECK:     LHS
-- CHECK:       COLUMN
-- CHECK:         COLUMN foo
-- CHECK:     OPERATOR REGEXP
-- CHECK:     RHS
-- CHECK:       LITERAL 'bar'
foo REGEXP 'bar';

-- CHECK: EXPRESSION_SYNTAX
-- CHECK:   INFIX
-- CHECK:     LHS
-- CHECK:       COLUMN
-- CHECK:         COLUMN foo
-- CHECK:     OPERATOR NOT MATCH
-- CHECK:     RHS
-- CHECK:       LITERAL 'bar'
foo NOT MATCH 'bar';

-- CHECK: EXPRESSION_SYNTAX
-- CHECK:   INFIX
-- CHECK:     LHS
-- CHECK:       COLUMN
-- CHECK:         COLUMN foo
-- CHECK:     OPERATOR MATCH
-- CHECK:     RHS
-- CHECK:       LITERAL 'bar'
foo MATCH 'bar';

-- CHECK: EXPRESSION_SYNTAX
-- CHECK:   POSTFIX
-- CHECK:     LHS
-- CHECK:       COLUMN
-- CHECK:         COLUMN foo
-- CHECK:     OPERATOR ISNULL
foo ISNULL;

-- CHECK: EXPRESSION_SYNTAX
-- CHECK:   POSTFIX
-- CHECK:     LHS
-- CHECK:       COLUMN
-- CHECK:         COLUMN foo
-- CHECK:     OPERATOR NOTNULL
foo NOTNULL;

-- CHECK: EXPRESSION_SYNTAX
-- CHECK:   POSTFIX
-- CHECK:     LHS
-- CHECK:       COLUMN
-- CHECK:         COLUMN foo
-- CHECK:     OPERATOR NOT NULL
foo NOT NULL;

-- CHECK: EXPRESSION_SYNTAX
-- CHECK:   INFIX
-- CHECK:     LHS
-- CHECK:       COLUMN
-- CHECK:         COLUMN foo
-- CHECK:     OPERATOR IS DISTINCT FROM
-- CHECK:     RHS
-- CHECK:       LITERAL 1.0
foo IS DISTINCT FROM 1;

-- CHECK: EXPRESSION_SYNTAX
-- CHECK:   INFIX
-- CHECK:     LHS
-- CHECK:       COLUMN
-- CHECK:         COLUMN foo
-- CHECK:     OPERATOR IS NOT DISTINCT FROM
-- CHECK:     RHS
-- CHECK:       LITERAL 1.0
foo IS NOT DISTINCT FROM 1;

-- CHECK: EXPRESSION_SYNTAX
-- CHECK:   INFIX
-- CHECK:     LHS
-- CHECK:       COLUMN
-- CHECK:         COLUMN foo
-- CHECK:     OPERATOR IS NOT
-- CHECK:     RHS
-- CHECK:       LITERAL 1.0
foo IS NOT 1;

-- CHECK: EXPRESSION_SYNTAX
-- CHECK:   INFIX
-- CHECK:     LHS
-- CHECK:       COLUMN
-- CHECK:         COLUMN foo
-- CHECK:     OPERATOR IS
-- CHECK:     RHS
-- CHECK:       LITERAL 1.0
foo IS 1;

-- CHECK: EXPRESSION_SYNTAX
-- CHECK:   BETWEEN
-- CHECK:     NOT false
-- CHECK:     VALUE
-- CHECK:       COLUMN
-- CHECK:         COLUMN foo
-- CHECK:     LOWER
-- CHECK:       LITERAL 1.0
-- CHECK:     UPPER
-- CHECK:       LITERAL 2.0
foo BETWEEN 1 AND 2;

-- CHECK: EXPRESSION_SYNTAX
-- CHECK:   BETWEEN
-- CHECK:     NOT false
-- CHECK:     VALUE
-- CHECK:       COLUMN
-- CHECK:         COLUMN foo
-- CHECK:     LOWER
-- CHECK:       INFIX
-- CHECK:         LHS
-- CHECK:           LITERAL 1.0
-- CHECK:         OPERATOR +
-- CHECK:         RHS
-- CHECK:           LITERAL 2.0
-- CHECK:     UPPER
-- CHECK:       INFIX
-- CHECK:         LHS
-- CHECK:           LITERAL 2.0
-- CHECK:         OPERATOR *
-- CHECK:         RHS
-- CHECK:           LITERAL 5.0
foo BETWEEN 1 + 2 AND 2 * 5;

-- CHECK: EXPRESSION_SYNTAX
-- CHECK:   BETWEEN
-- CHECK:     NOT true
-- CHECK:     VALUE
-- CHECK:       COLUMN
-- CHECK:         COLUMN foo
-- CHECK:     LOWER
-- CHECK:       LITERAL 1.0
-- CHECK:     UPPER
-- CHECK:       LITERAL 2.0
foo NOT BETWEEN 1 AND 2;

-- CHECK: EXPRESSION_SYNTAX
-- CHECK:   INFIX
-- CHECK:     LHS
-- CHECK:       COLUMN
-- CHECK:         COLUMN foo
-- CHECK:     OPERATOR IN
-- CHECK:     RHS
-- CHECK:       GROUPED
-- CHECK:         EXPRS
-- CHECK:           EXPRESSION_SYNTAX
-- CHECK:             LITERAL 1.0
-- CHECK:           EXPRESSION_SYNTAX
-- CHECK:             LITERAL 2.0
-- CHECK:           EXPRESSION_SYNTAX
-- CHECK:             LITERAL 3.0
foo IN (1, 2, 3);

-- CHECK: EXPRESSION_SYNTAX
-- CHECK:   INFIX
-- CHECK:     LHS
-- CHECK:       COLUMN
-- CHECK:         COLUMN foo
-- CHECK:     OPERATOR NOT IN
-- CHECK:     RHS
-- CHECK:       GROUPED
-- CHECK:         EXPRS
-- CHECK:           EXPRESSION_SYNTAX
-- CHECK:             LITERAL 1.0
-- CHECK:           EXPRESSION_SYNTAX
-- CHECK:             LITERAL 2.0
-- CHECK:           EXPRESSION_SYNTAX
-- CHECK:             LITERAL 3.0
foo NOT IN (1, 2, 3);

-- CHECK: EXPRESSION_SYNTAX
-- CHECK:   INFIX
-- CHECK:     LHS
-- CHECK:       COLUMN
-- CHECK:         COLUMN foo
-- CHECK:     OPERATOR IN
-- CHECK:     RHS
-- CHECK:       FN
-- CHECK:         TABLE foo
-- CHECK:         NAME baz
-- CHECK:         ARGS
-- CHECK:           EXPRESSION_SYNTAX
-- CHECK:             LITERAL 1.0
foo IN foo.baz(1);

-- CHECK: EXPRESSION_SYNTAX
-- CHECK:   INFIX
-- CHECK:     LHS
-- CHECK:       COLUMN
-- CHECK:         COLUMN foo
-- CHECK:     OPERATOR IN
-- CHECK:     RHS
-- CHECK:       COLUMN
-- CHECK:         TABLE foo
-- CHECK:         COLUMN baz
foo IN foo.baz;

-- CHECK: EXPRESSION_SYNTAX
-- CHECK:   CASE_WHEN_THEN
-- CHECK:     CASE
-- CHECK:       COLUMN
-- CHECK:         COLUMN foo
-- CHECK:     WHEN_THEN
-- CHECK:       WHEN_THEN
-- CHECK:         WHEN
-- CHECK:           LITERAL 1.0
-- CHECK:         THEN
-- CHECK:           LITERAL 'one'
-- CHECK:       WHEN_THEN
-- CHECK:         WHEN
-- CHECK:           LITERAL 2.0
-- CHECK:         THEN
-- CHECK:           LITERAL 'two'
-- CHECK:       WHEN_THEN
-- CHECK:         WHEN
-- CHECK:           LITERAL 3.0
-- CHECK:         THEN
-- CHECK:           LITERAL 'three'
CASE foo WHEN 1 THEN 'one' WHEN 2 THEN 'two' WHEN 3 THEN 'three' END;

-- CHECK: EXPRESSION_SYNTAX
-- CHECK:   CASE_WHEN_THEN
-- CHECK:     WHEN_THEN
-- CHECK:       WHEN_THEN
-- CHECK:         WHEN
-- CHECK:           LITERAL 1.0
-- CHECK:         THEN
-- CHECK:           LITERAL 'one'
-- CHECK:       WHEN_THEN
-- CHECK:         WHEN
-- CHECK:           LITERAL 2.0
-- CHECK:         THEN
-- CHECK:           LITERAL 'two'
-- CHECK:       WHEN_THEN
-- CHECK:         WHEN
-- CHECK:           LITERAL 3.0
-- CHECK:         THEN
-- CHECK:           LITERAL 'three'
CASE WHEN 1 THEN 'one' WHEN 2 THEN 'two' WHEN 3 THEN 'three' END;

-- CHECK: EXPRESSION_SYNTAX
-- CHECK:   CASE_WHEN_THEN
-- CHECK:     WHEN_THEN
-- CHECK:       WHEN_THEN
-- CHECK:         WHEN
-- CHECK:           LITERAL 1.0
-- CHECK:         THEN
-- CHECK:           LITERAL 'one'
-- CHECK:       WHEN_THEN
-- CHECK:         WHEN
-- CHECK:           LITERAL 2.0
-- CHECK:         THEN
-- CHECK:           LITERAL 'two'
-- CHECK:       WHEN_THEN
-- CHECK:         WHEN
-- CHECK:           LITERAL 3.0
-- CHECK:         THEN
-- CHECK:           LITERAL 'three'
-- CHECK:     ELSE
-- CHECK:       LITERAL 'meh'
CASE WHEN 1 THEN 'one' WHEN 2 THEN 'two' WHEN 3 THEN 'three' ELSE 'meh' END;

-- CHECK: EXPRESSION_SYNTAX
-- CHECK:   INFIX
-- CHECK:     LHS
-- CHECK:       COLUMN
-- CHECK:         COLUMN foo
-- CHECK:     OPERATOR IS
-- CHECK:     RHS
-- CHECK:       LITERAL NULL
foo IS NULL;

-- CHECK: EXPRESSION_SYNTAX
-- CHECK:   INFIX
-- CHECK:     LHS
-- CHECK:       COLUMN
-- CHECK:         COLUMN foo
-- CHECK:     OPERATOR IS DISTINCT FROM
-- CHECK:     RHS
-- CHECK:       LITERAL NULL
foo IS DISTINCT FROM NULL;

-- CHECK: EXPRESSION_SYNTAX
-- CHECK:   BETWEEN
-- CHECK:     NOT false
-- CHECK:     VALUE
-- CHECK:       COLUMN
-- CHECK:         COLUMN foo
-- CHECK:     LOWER
-- CHECK:       LITERAL 1.0
-- CHECK:     UPPER
-- CHECK:       LITERAL 2.0
foo BETWEEN 1 AND 2;

-- CHECK: EXPRESSION_SYNTAX
-- CHECK:   BETWEEN
-- CHECK:     NOT false
-- CHECK:     VALUE
-- CHECK:       COLUMN
-- CHECK:         COLUMN foo
-- CHECK:     LOWER
-- CHECK:       INFIX
-- CHECK:         LHS
-- CHECK:           LITERAL 1.0
-- CHECK:         OPERATOR +
-- CHECK:         RHS
-- CHECK:           LITERAL 2.0
-- CHECK:     UPPER
-- CHECK:       INFIX
-- CHECK:         LHS
-- CHECK:           LITERAL 2.0
-- CHECK:         OPERATOR *
-- CHECK:         RHS
-- CHECK:           LITERAL 5.0
foo BETWEEN 1 + 2 AND 2 * 5;

-- CHECK: EXPRESSION_SYNTAX
-- CHECK:   BETWEEN
-- CHECK:     NOT true
-- CHECK:     VALUE
-- CHECK:       COLUMN
-- CHECK:         COLUMN foo
-- CHECK:     LOWER
-- CHECK:       LITERAL 1.0
-- CHECK:     UPPER
-- CHECK:       LITERAL 2.0
foo NOT BETWEEN 1 AND 2;
