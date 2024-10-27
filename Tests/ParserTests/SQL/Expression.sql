-- CHECK: ((1.0 + 2.0) + 3.0)
1 + 2 + 3

-- CHECK: (1.0 - 2.0)
1 - 2

-- CHECK: (infix op: +
-- CHECK:   lhs: (infix op: +
-- CHECK:     lhs: (literal kind: numeric: 1.0, isInt: true)
-- CHECK:     rhs: (literal kind: numeric: 1.0, isInt: true))
-- CHECK:   rhs: (literal kind: numeric: 1.0, isInt: true))

