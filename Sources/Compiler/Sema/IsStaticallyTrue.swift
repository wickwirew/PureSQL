//
//  IsStaticallyTrue.swift
//  Feather
//
//  Created by Wes Wickwire on 2/21/25.
//

/// Determines whether a value can be considered `true` at compile time.
struct IsStaticallyTrue: ExprSyntaxVisitor {
    /// If `true`, text of `on, off, yes and no` are valid values.
    let allowOnOffYesNo: Bool
    
    private(set) var diagnostics = Diagnostics()
    
    mutating func isTrue(_ expr: ExprSyntax) -> Bool {
        return expr.accept(visitor: &self)
    }
    
    mutating func visit(_ expr: BindParameterSyntax) -> Bool {
        emitNotBoolDiag(for: expr)
        return false
    }
    
    mutating func visit(_ expr: ColumnExprSyntax) -> Bool {
        return false
    }
    
    mutating func visit(_ expr: PrefixExprSyntax) -> Bool {
        emitNotBoolDiag(for: expr)
        return false
    }
    
    mutating func visit(_ expr: InfixExprSyntax) -> Bool {
        emitNotBoolDiag(for: expr)
        return false
    }
    
    mutating func visit(_ expr: PostfixExprSyntax) -> Bool {
        emitNotBoolDiag(for: expr)
        return false
    }
    
    mutating func visit(_ expr: BetweenExprSyntax) -> Bool {
        emitNotBoolDiag(for: expr)
        return false
    }
    
    mutating func visit(_ expr: FunctionExprSyntax) -> Bool {
        emitNotBoolDiag(for: expr)
        return false
    }
    
    mutating func visit(_ expr: CastExprSyntax) -> Bool {
        emitNotBoolDiag(for: expr)
        return false
    }
    
    mutating func visit(_ expr: CaseWhenThenExprSyntax) -> Bool {
        emitNotBoolDiag(for: expr)
        return false
    }
    
    mutating func visit(_ expr: GroupedExprSyntax) -> Bool {
        emitNotBoolDiag(for: expr)
        return false
    }
    
    mutating func visit(_ expr: SelectExprSyntax) -> Bool {
        emitNotBoolDiag(for: expr)
        return false
    }
    
    mutating func visit(_ expr: InvalidExprSyntax) -> Bool {
        emitNotBoolDiag(for: expr)
        return false
    }
    
    mutating func visit(_ expr: LiteralExprSyntax) -> Bool {
        switch expr.kind {
        case .numeric(let numericSyntax, _):
            return numericSyntax != 0
        case .true:
            return true
        case .false:
            return false
        case .string(let text):
            guard allowOnOffYesNo else {
                emitNotBoolDiag(for: expr)
                return false
            }
            
            switch text.uppercased() {
            case "YES", "ON": return true
            case "NO", "OFF": return false
            default:
                emitNotBoolDiag(for: expr)
                return false
            }
        default:
            emitNotBoolDiag(for: expr)
            return false
        }
    }
    
    mutating func visit(_ expr: ExistsExprSyntax) -> Bool {
        emitNotBoolDiag(for: expr)
        return false
    }
    
    private mutating func emitNotBoolDiag<S: Syntax>(for syntax: S) {
        diagnostics.add(.init(
            "Value is not a static integerean, expected TRUE, FALSE, 1 or 0",
            at: syntax.location
        ))
    }
}
