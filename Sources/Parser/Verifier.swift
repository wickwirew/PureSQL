//
//  Verifier.swift
//
//
//  Created by Wes Wickwire on 10/22/24.
//

import Schema

struct ExprVerifier: ExprVisitor {
    mutating func visit(_ expr: LiteralExpr) throws -> String {
        let kind: String = switch expr.kind {
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
        
        return "(literal \(kind))"
    }
    
    mutating func visit(_ expr: BindParameter) throws -> String {
        let kind = switch expr.kind {
        case .named(let i): "named: \(i)"
        case .unnamed: "unamed"
        }
        
        return "(bind-parameter \(kind))"
    }
    
    mutating func visit(_ expr: ColumnExpr) throws -> String {
        return "(column \(expr.description))"
    }
    
    mutating func visit(_ expr: PrefixExpr) throws -> String {
        return "(prefix operator: \(expr.operator) rhs: \(try expr.rhs.accept(visitor: &self)))"
    }
    
    mutating func visit(_ expr: InfixExpr) throws -> String {
        let lhs = try expr.lhs.accept(visitor: &self)
        let rhs = try expr.rhs.accept(visitor: &self)
        return "(prefix lhs: \(lhs) operator: \(expr.operator) rhs: \(rhs))"
    }
    
    mutating func visit(_ expr: PostfixExpr) throws -> String {
        let lhs = try expr.lhs.accept(visitor: &self)
        return "(postfix lhs: \(lhs) operator: \(expr.operator))"
    }
    
    mutating func visit(_ expr: BetweenExpr) throws -> String {
        let value = try expr.value.accept(visitor: &self)
        let lower = try expr.lower.accept(visitor: &self)
        let upper = try expr.upper.accept(visitor: &self)
        return "(between value: \(value) lower: \(lower) upper: \(upper))"
    }
    
    mutating func visit(_ expr: FunctionExpr) throws -> String {
        let args = try expr.args
            .map { try $0.accept(visitor: &self) }
            .joined(separator: ", ")
        
        return "(function name: \(expr.name) args: \(args))"
    }
    
    mutating func visit(_ expr: CastExpr) throws -> String {
        let value = try expr.expr.accept(visitor: &self)
        return "(cast expr: \(value) type: \(expr.ty.name))"
    }
    
    mutating func visit(_ expr: CaseWhenThenExpr) throws -> String {
        let whens = try expr.whenThen.map { whenThen in
            let when = try whenThen.when.accept(visitor: &self)
            let then = try whenThen.then.accept(visitor: &self)
            return "(when: \(when) then: \(then)"
        }
        .joined(separator: ", ")
        
        let el = try expr.else?.accept(visitor: &self)
        
        return "(caseWhenThen cases: \(whens)\(el.map { " else: \($0)" } ?? ""))"
    }
    
    mutating func visit(_ expr: GroupedExpr) throws -> String {
        let exprs = try expr.exprs
            .map { try $0.accept(visitor: &self) }
            .joined(separator: ", ")
        
        return "(grouped \(exprs))"
    }
}
