//
//  Verifications.swift
//  SQL
//
//  Created by Wes Wickwire on 10/27/24.
//

import Schema

extension Expression: Verifiable {
    var verification: Verification {
        switch self {
        case .literal(let e): e.verification
        case .bindParameter(let e): e.verification
        case .column(let e): e.verification
        case .prefix(let e): e.verification
        case .infix(let e): e.verification
        case .postfix(let e): e.verification
        case .between(let e): e.verification
        case .fn(let e): e.verification
        case .cast(let e): e.verification
        case .grouped(let e): e.verification
        case .caseWhenThen(let e): e.verification
        }
    }
}

extension LiteralExpr: Verifiable {
    var verification: Verification {
        let kind: String = switch kind {
        case .numeric(let n, let isInt): "numeric: \(n), isInt: \(isInt)"
        case .string(let s): "string: \(s)"
        case .blob(let s): "blob: \(s)"
        case .null: "null"
        case .true: "true"
        case .false: "false"
        case .currentTime: "current-time"
        case .currentDate: "current-date"
        case .currentTimestamp: "current-timestamp"
        }
        
        return Verification("literal") { properties in
            properties.append(.string("kind", kind))
        }
    }
}

extension BindParameter: Verifiable {
    var verification: Verification  {
        let kind = switch kind {
        case .named(let ident): "named(\(ident.name))"
        case .unnamed: "unnamed"
        }
        
        return Verification("bind-param") { properties in
            properties.append(.string("kind", kind))
        }
    }
}

extension ColumnExpr: Verifiable {
    var verification: Verification  {
        return Verification("column") { properties in
            properties.append(.string("column", description))
        }
    }
}

extension PrefixExpr: Verifiable {
    var verification: Verification  {
        return Verification("prefix") { properties in
            properties.append(.string("op", value: self.operator))
            properties.append(.verification("rhs", value: rhs))
        }
    }
}

extension InfixExpr: Verifiable {
    var verification: Verification  {
        return Verification("infix") { properties in
            properties.append(.string("op", value: self.operator))
            properties.append(.verification("lhs", value: lhs))
            properties.append(.verification("rhs", value: rhs))
        }
    }
}

extension PostfixExpr: Verifiable {
    var verification: Verification  {
        return Verification("postfix") { properties in
            properties.append(.string("op", value: self.operator))
            properties.append(.verification("lhs", value: lhs))
        }
    }
}

extension BetweenExpr: Verifiable {
    var verification: Verification  {
        return Verification("between") { properties in
            properties.append(.verification("value", value: value))
            properties.append(.verification("lower", value: lower))
            properties.append(.verification("upper", value: upper))
        }
    }
}

extension FunctionExpr: Verifiable {
    var verification: Verification  {
        return Verification("function") { properties in
            for arg in args {
                properties.append(.verification("args", value: arg))
            }
        }
    }
}

extension CastExpr: Verifiable {
    var verification: Verification  {
        return Verification("cast") { properties in
            properties.append(.string("type", value: ty))
            properties.append(.verification("expr", value: expr))
        }
    }
}

extension GroupedExpr: Verifiable {
    var verification: Verification  {
        return Verification("group") { properties in
            for value in exprs {
                properties.append(.verification("value", value: value))
            }
        }
    }
}

extension CaseWhenThenExpr: Verifiable {
    var verification: Verification  {
        return Verification("case") { properties in
            if let expr = `case` {
                properties.append(.verification("case", value: expr))
            } else {
                properties.append(.string("case", "none"))
            }
            
            for whenThen in whenThen {
                let verification = Verification { properties in
                    properties.append(.verification("when", value: whenThen.when))
                    properties.append(.verification("then", value: whenThen.then))
                }
                
                properties.append(.verification("whenThen", verification))
            }
        }
    }
}

extension ForeignKeyClause: Verifiable {
    var verification: Verification {
        return Verification("foreign-key-clause") { properties in
            properties.append(.string("table", value: foreignTable))
            properties.append(.string("columns", value: foreignColumns.map(\.name).joined(separator: ",")))
        }
    }
}
//
//extension ColumnConstraint: Verifiable {
//    var verification: Verification {
//        return Verification("column-constraint") { properties in
//            properties.append(.optional("name", value: name))
//            
//            let kind: Verification = switch kind {
//            case let .primaryKey(order, confictClause, autoincrement):
//                Verification("primary-key") { properties in
//                    properties.append(.string("order", "\(order)"))
//                    properties.append(.string("confictClause", "\(confictClause)"))
//                    properties.append(.string("autoincrement", "\(autoincrement)"))
//                }
//            case let .notNull(confictClause):
//                Verification("not-null") { properties in
//                    properties.append(.string("confictClause", "\(confictClause)"))
//                }
//            case let .unique(confictClause):
//                Verification("unique") { properties in
//                    properties.append(.string("confictClause", "\(confictClause)"))
//                }
//            case let .check(expression):
//                Verification("check") { properties in
//                    properties.append(.verification("expr", value: expression))
//                }
//            case let .`default`(def):
//                Verification("default") { properties in
//                    switch def {
//                    case .expr(let expr):
//                        properties.append(.verification("value", value: expr))
//                    case .literal(let lit):
//                        properties.append(.verification("value", value: lit))
//                    }
//                }
//            case let .collate(identifier):
//                Verification("collate") { properties in
//                    properties.append(.string("name", value: identifier))
//                }
//            case let .foreignKey(foreignKeyClause):
//                Verification("foreign-key") { _ in }
//            case let .generated(expression, generatedKind):
//                Verification("generated") { _ in }
//            }
//        }
//    }
//}
