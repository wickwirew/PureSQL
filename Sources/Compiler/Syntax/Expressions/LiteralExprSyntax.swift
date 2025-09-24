//
//  LiteralExprSyntax.swift
//  PureSQL
//
//  Created by Wes Wickwire on 5/7/25.
//

/// https://www.sqlite.org/syntax/literal-value.html
struct LiteralExprSyntax: ExprSyntax {
    let id: SyntaxId
    let kind: Kind
    let location: SourceLocation

    enum Kind {
        case numeric(NumericSyntax, isInt: Bool)
        case string(Substring)
        case blob(Substring)
        case null
        case `true`
        case `false`
        case currentTime
        case currentDate
        case currentTimestamp
        case invalid
    }

    func accept<V>(visitor: inout V) -> V.ExprOutput where V : ExprSyntaxVisitor {
        return visitor.visit(self)
    }
}

extension LiteralExprSyntax: CustomStringConvertible {
    var description: String {
        switch self.kind {
        case let .numeric(numeric, _):
            return numeric.description
        case let .string(substring):
            return "'\(substring.description)'"
        case let .blob(substring):
            return substring.description
        case .null:
            return "NULL"
        case .true:
            return "TRUE"
        case .false:
            return "FALSE"
        case .currentTime:
            return "CURRENT_TIME"
        case .currentDate:
            return "CURRENT_DATE"
        case .currentTimestamp:
            return "CURRENT_TIMESTAMP"
        case .invalid:
            return "<<invalid>>"
        }
    }
}
