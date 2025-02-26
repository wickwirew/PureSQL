//
//  IsStaticallyTrue.swift
//  Feather
//
//  Created by Wes Wickwire on 2/21/25.
//

/// Determines whether a value can be considered `true` at compile time.
struct IsStaticallyTrue: ExprSyntaxVisitor {
    let allowOnOff: Bool
    
    mutating func visit(_ expr: borrowing BindParameterSyntax) -> Bool { false }
    
    mutating func visit(_ expr: borrowing ColumnExprSyntax) -> Bool {
        guard allowOnOff, expr.schema == nil, expr.table == nil else {
            return false
        }
        
        switch expr.column.value.uppercased() {
        case "ON": return true
        case "OFF": return false
        default:
            return false
        }
    }
    
    mutating func visit(_ expr: borrowing PrefixExprSyntax) -> Bool { false }
    
    mutating func visit(_ expr: borrowing InfixExprSyntax) -> Bool { false }
    
    mutating func visit(_ expr: borrowing PostfixExprSyntax) -> Bool { false }
    
    mutating func visit(_ expr: borrowing BetweenExprSyntax) -> Bool { false }
    
    mutating func visit(_ expr: borrowing FunctionExprSyntax) -> Bool { false }
    
    mutating func visit(_ expr: borrowing CastExprSyntax) -> Bool { false }
    
    mutating func visit(_ expr: borrowing CaseWhenThenExprSyntax) -> Bool { false }
    
    mutating func visit(_ expr: borrowing GroupedExprSyntax) -> Bool { false }
    
    mutating func visit(_ expr: borrowing SelectExprSyntax) -> Bool { false }
    
    mutating func visit(_ expr: borrowing InvalidExprSyntax) -> Bool { false }
    
    mutating func visit(_ expr: borrowing LiteralExprSyntax) -> Bool {
        switch expr.kind {
        case .numeric(let numericSyntax, _):
            return numericSyntax != 0
        case .true:
            return true
        case .false:
            return false
        default:
            return false
        }
    }
}
