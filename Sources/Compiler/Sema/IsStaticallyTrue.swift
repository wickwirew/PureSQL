//
//  IsStaticallyTrue.swift
//  Feather
//
//  Created by Wes Wickwire on 2/21/25.
//

/// Determines whether a value can be considered `true` at compile time.
struct IsStaticallyTrue: ExprSyntaxVisitor {
    let allowOnOff: Bool
    private(set) var diagnostics = Diagnostics()
    
    mutating func visit(_ expr: borrowing BindParameterSyntax) -> Bool {
        emitNotBoolDiag(for: expr)
        return false
    }
    
    mutating func visit(_ expr: borrowing ColumnExprSyntax) -> Bool {
        guard allowOnOff, expr.schema == nil, expr.table == nil else {
            emitNotBoolDiag(for: expr)
            return false
        }
        
        switch expr.column.value.uppercased() {
        case "ON": return true
        case "OFF": return false
        default:
            emitNotBoolDiag(for: expr)
            return false
        }
    }
    
    mutating func visit(_ expr: borrowing PrefixExprSyntax) -> Bool {
        emitNotBoolDiag(for: expr)
        return false
    }
    
    mutating func visit(_ expr: borrowing InfixExprSyntax) -> Bool {
        emitNotBoolDiag(for: expr)
        return false
    }
    
    mutating func visit(_ expr: borrowing PostfixExprSyntax) -> Bool {
        emitNotBoolDiag(for: expr)
        return false
    }
    
    mutating func visit(_ expr: borrowing BetweenExprSyntax) -> Bool {
        emitNotBoolDiag(for: expr)
        return false
    }
    
    mutating func visit(_ expr: borrowing FunctionExprSyntax) -> Bool {
        emitNotBoolDiag(for: expr)
        return false
    }
    
    mutating func visit(_ expr: borrowing CastExprSyntax) -> Bool {
        emitNotBoolDiag(for: expr)
        return false
    }
    
    mutating func visit(_ expr: borrowing CaseWhenThenExprSyntax) -> Bool {
        emitNotBoolDiag(for: expr)
        return false
    }
    
    mutating func visit(_ expr: borrowing GroupedExprSyntax) -> Bool {
        emitNotBoolDiag(for: expr)
        return false
    }
    
    mutating func visit(_ expr: borrowing SelectExprSyntax) -> Bool {
        emitNotBoolDiag(for: expr)
        return false
    }
    
    mutating func visit(_ expr: borrowing InvalidExprSyntax) -> Bool {
        emitNotBoolDiag(for: expr)
        return false
    }
    
    mutating func visit(_ expr: borrowing LiteralExprSyntax) -> Bool {
        switch expr.kind {
        case .numeric(let numericSyntax, _):
            return numericSyntax != 0
        case .true:
            return true
        case .false:
            return false
        default:
            diagnostics.add(.init(
                "Value is not a static boolean, expected TRUE, FALSE, 1 or 0",
                at: expr.range
            ))
            return false
        }
    }
    
    private mutating func emitNotBoolDiag<S: Syntax>(for syntax: S) {
        diagnostics.add(.init(
            "Value is not a static boolean, expected TRUE, FALSE, 1 or 0",
            at: syntax.range
        ))
    }
}
