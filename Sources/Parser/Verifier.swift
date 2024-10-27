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


struct ExprVerifier2: ExprVisitor {
    var builder = VerificationStringBuilder()
    
    mutating func visit(_ expr: LiteralExpr) throws {
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
        
        builder.start(name: "literal")
        builder.add(property: "kind", with: kind)
        builder.end()
    }
    
    mutating func visit(_ expr: BindParameter) throws {
        let kind = switch expr.kind {
        case .named(let i): "named: \(i)"
        case .unnamed: "unamed"
        }
        
        builder.start(name: "bind-parameter")
        builder.add(property: "kind", with: kind)
        builder.end()
    }
    
    mutating func visit(_ expr: ColumnExpr) throws {
        builder.start(name: "column")
        builder.add(property: "value", with: expr.description)
        builder.end()
    }
    
    mutating func visit(_ expr: PrefixExpr) throws {
        builder.start(name: "prefix")
        builder.add(property: "op", with: expr.operator.description)
        builder.start(property: "rhs")
        try expr.rhs.accept(visitor: &self)
        builder.endProperty()
        builder.endLine()
    }
    
    mutating func visit(_ expr: InfixExpr) throws {
        builder.start(name: "infix")
        builder.add(property: "op", with: expr.operator.description)
        builder.break()
        builder.start(property: "lhs")
        try expr.lhs.accept(visitor: &self)
        builder.newline()
        builder.start(property: "rhs")
        try expr.rhs.accept(visitor: &self)
//        builder.unbreak()
        builder.endLine()
    }
    
    mutating func visit(_ expr: PostfixExpr) throws {
        builder.start(name: "postfix")
        builder.add(property: "op", with: expr.operator.description)
        builder.start(property: "lhs")
        try expr.lhs.accept(visitor: &self)
        builder.endProperty()
        builder.endLine()
    }
    
    mutating func visit(_ expr: BetweenExpr) throws {
        builder.start(name: "between")
        builder.start(property: "value")
        try expr.value.accept(visitor: &self)
        builder.endProperty()
        builder.start(property: "lower")
        try expr.lower.accept(visitor: &self)
        builder.endProperty()
        builder.start(property: "upper")
        try expr.upper.accept(visitor: &self)
        builder.endProperty()
        builder.endLine()
    }
    
    mutating func visit(_ expr: FunctionExpr) throws {
        builder.start(name: "function")
        builder.add(property: "name", with: expr.name.description)
        builder.start(property: "args")
        
        for arg in expr.args {
            try arg.accept(visitor: &self)
        }
        
        builder.endProperty()
        builder.endLine()
    }
    
    mutating func visit(_ expr: CastExpr) throws {
        builder.start(name: "cast")
        builder.start(name: "expr")
        try expr.expr.accept(visitor: &self)
        builder.endProperty()
        builder.add(property: "ty", with: expr.ty.description)
        builder.endLine()
    }
    
    mutating func visit(_ expr: CaseWhenThenExpr) throws {
//        let whens = try expr.whenThen.map { whenThen in
//            let when = try whenThen.when.accept(visitor: &self)
//            let then = try whenThen.then.accept(visitor: &self)
//            return "(when: \(when) then: \(then)"
//        }
//        .joined(separator: ", ")
//        
//        let el = try expr.else?.accept(visitor: &self)
//        
//        return "(caseWhenThen cases: \(whens)\(el.map { " else: \($0)" } ?? ""))"
//        
//        builder.start(name: "caseWhenThen")
//        builder.start(property: "cases", break: true)
//        
//        for whenThen in expr.whenThen {
//            try whenThen.when.accept(visitor: &self)
//            try whenThen.then.accept(visitor: &self)
//        }
//        
//
        fatalError()
    }
    
    mutating func visit(_ expr: GroupedExpr) throws {
        builder.start(name: "grouped")
        builder.start(property: "exprs")
        
        for expr in expr.exprs {
            try expr.accept(visitor: &self)
        }
        
        builder.endProperty()
        builder.endLine()
    }
}

struct VerificationStringBuilder {
    private var lines: [String] = [""]
    private var indentation: Int = 0
    
    var result: String {
        return lines.joined(separator: "\n")
    }
    
    var current: String {
        get { lines.last ?? "" }
        set { lines[lines.count - 1] = newValue }
    }
    
    mutating func start(name: String) {
        current.append("(\(name)")
    }
    
    mutating func `break`() {
        indentation += 1
        lines.append(indent())
    }
    
    mutating func unbreak() {
        indentation -= 1
        lines.append(indent())
    }
    
    mutating func newline() {
        lines.append(indent())
    }
    
    mutating func add(property: String, with value: String) {
        current.append(" \(property): \(value)")
    }
    
    mutating func start(property: String) {
        current.append("\(property): ")
    }
    
    mutating func endProperty() {
        indentation -= 1
    }
    
    mutating func end() {
        current.append(")")
    }
    
    mutating func endLine() {
        current.append(")")
        indentation -= 1
    }
    
    private func indent() -> String {
        return String(repeating: " ", count: indentation * 2)
    }
}

/*
 (infix
    operat
    lhs: (1.2))
 */
