-- CHECK: (infix op: +,
-- CHECK:   lhs: (infix op: +,
-- CHECK:     lhs: (literal kind: numeric: 1.0, isInt: true),
-- CHECK:     rhs: (literal kind: numeric: 2.0, isInt: true)),
-- CHECK:   rhs: (literal kind: numeric: 3.0, isInt: true))
1 + 2 + 3
