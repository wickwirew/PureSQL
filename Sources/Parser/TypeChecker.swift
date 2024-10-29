//
//  TypeChecker.swift
//
//
//  Created by Wes Wickwire on 10/19/24.
//

import OrderedCollections
import Schema

struct Scope {
    private(set) var tables: [TableName: TableSchema] = [:]
    private let schema: DatabaseSchema
    
    enum ColumnResult: Equatable {
        case found(ColumnDef)
        case ambiguous
        case notFound
    }
    
    init(tables: [TableName: TableSchema] = [:], schema: DatabaseSchema = DatabaseSchema(tables: [:])) {
        self.tables = tables
        self.schema = schema
    }
    
    mutating func include(schema: Identifier?, table: Identifier) -> Bool {
        let name = TableName(schema: schema, name: table)
        guard let table = self.schema.tables[name] else { return false }
        tables[name] = table
        return true
    }
    
    func column(name: Identifier) -> ColumnResult {
        var result: ColumnResult = .notFound
        
        for table in tables.values {
            if let column = table.columns[name] {
                if result != .notFound {
                    return .ambiguous
                }
                
                result = .found(column)
            }
        }
        
        return result
    }
    
    func column(
        schema: Identifier?,
        table: Identifier,
        name: Identifier
    ) -> ColumnResult {
        guard let table = tables[TableName(schema: schema, name: table)],
              let column = table.columns[name] else { return .notFound }
        
        return .found(column)
    }
}

struct CompiledQuery {
    let input: [Field<BindParameter>]
    let output: [Field<Substring>]
    
    struct Field<Name> {
        let name: Name
        let type: TypeName
        let nullable: Bool
        
        init(name: Name, type: TypeName, nullable: Bool) {
            self.name = name
            self.type = type
            self.nullable = nullable
        }
    }
}

struct Solution {
    let type: Ty
    private let names: Names
    private let substitution: Substitution
    private let tyVarLookup: [BindParameter.Kind: TypeVariable]
    
    init(
        type: Ty,
        names: Names,
        substitution: Substitution,
        tyVarLookup: [BindParameter.Kind : TypeVariable]
    ) {
        self.type = type
        self.names = names
        self.substitution = substitution
        self.tyVarLookup = tyVarLookup
    }
    
    func type(for param: BindParameter.Kind) -> TypeName {
        guard let tv = tyVarLookup[param] else { fatalError("TODO: Throw real error") }
        
        // TODO: More errors and diag
        switch Ty.var(tv).apply(substitution) {
        case .nominal(let t): return t
        case .var: return .any
        case .error: return .any
        }
    }
    
    func name(for index: Int) -> Substring {
        return names.map[index] ?? "value"
    }
}

struct TypeVariable: Hashable, CustomStringConvertible {
    let n: Int
    
    init(_ n: Int) {
        self.n = n
    }
    
    var description: String {
        return "τ\(n)"
    }
}

typealias Substitution = [TypeVariable: Ty]

enum Ty: Equatable, CustomStringConvertible {
    case nominal(TypeName)
    case `var`(TypeVariable)
    case error
    
    static let text: Ty = .nominal(TypeName(name: "TEXT", args: nil, resolved: .text))
    static let int: Ty = .nominal(TypeName(name: "INT", args: nil, resolved: .int))
    static let integer: Ty = .nominal(TypeName(name: "INTEGER", args: nil, resolved: .integer))
    static let real: Ty = .nominal(TypeName(name: "REAL", args: nil, resolved: .real))
    static let blob: Ty = .nominal(TypeName(name: "BLOB", args: nil, resolved: .blob))
    static let any: Ty = .nominal(TypeName(name: "ANY", args: nil, resolved: .any))
    static let bool: Ty = .nominal(TypeName(name: "BOOL", args: nil, resolved: .int))
    
    var description: String {
        return switch self {
        case .nominal(let typeName): typeName.description
        case .var(let typeVariable): typeVariable.description
        case .error: "<<error>>"
        }
    }
    
    func apply(_ s : Substitution) -> Ty {
        // To apply a substitution to a type:
        switch self {
        case let .var(n):
            // If it's a type variable, look it up in the substitution map to
            // find a replacement.
            if let t = s[n] {
                // If we get replaced with ourself we've reached the desired fixpoint.
                if t == self {
                    return t
                }
                // Otherwise keep substituting.
                return t.apply(s)
            }
            return self
        case .nominal, .error:
            // Literals can't be substituted for.
            return self
        }
    }
    
    /// Unifies the two types together. Will produce a substitution if one
    /// is a type variable. If there are two nominal types they and
    /// they can be coerced en empty substitution will be return with
    /// the coerced type.
    func unify(with ty : Ty) -> (Substitution, Ty) {
        // If they are the same, no need to unify
        guard self != ty else { return ([:], self) }
        
        switch (self, ty) {
        case let (.var(tv), ty):
            return ([tv: ty], ty)
        case let (ty, .var(tv)):
            return ([tv: ty], ty)
        case let (.nominal(t1), .nominal(t2)):
            // No substitution can be made for two nominal types.
            // But we can return a coerced type if able.
            // This is how we can promote an INTEGER to a REAL
            switch (t1, t2) {
            case (.integer, .int): return ([:], .integer)
            case (.int, .integer): return ([:], .integer)
            case (.integer, .real): return ([:], .real)
            case (.real, .integer): return ([:], .real)
            case (.int, .real): return ([:], .real)
            case (.real, .int): return ([:], .real)
            case (.text, _): return ([:], .text)
            case (_, .text): return ([:], .text)
            default: return ([:], .any)
            }
        case let (.error, ty):
            return ([:], ty)
        case let (ty, .error):
            return ([:], ty)
        default:
            // Unification failed, return an error type
            return ([:], .error)
        }
      }
}

struct Names {
    let last: Name
    let map: [Int: Substring]
    
    enum Name {
        case needed(index: Int)
        case some(Substring)
        case none
    }
    
    static let none = Names(last: .none, map: [:])
    
    static func some(_ value: Substring) -> Names {
        return Names(last: .some(value), map: [:])
    }
    
    static func needed(index: Int) -> Names {
        return Names(last: .needed(index: index), map: [:])
    }
    
    func merging(with other: Names) -> Names {
        switch (last, other.last) {
        case let (.needed(index), .some(name)):
            var map = map
            map[index] = name
            return Names(last: .none, map: map)
        case let (.some(name), .needed(index)):
            var map = map
            map[index] = name
            return Names(last: .none, map: map)
        default:
            return self
        }
    }
}

struct TypeChecker {
    private let scope: Scope
    private var diagnostics: Diagnostics
    private var tyVars = 0
    private var tyVarLookup: [BindParameter.Kind: TypeVariable] = [:]
    private var names: [Int: Substring] = [:]
    
    init(scope: Scope, diagnostics: Diagnostics = Diagnostics()) {
        self.scope = scope
        self.diagnostics = diagnostics
    }
    
    private mutating func freshTyVar(for param: BindParameter) -> TypeVariable {
        defer { tyVars += 1 }
        let ty = TypeVariable(tyVars)
        tyVarLookup[param.kind] = ty
        return ty
    }
    
    mutating func check<E: Expr>(_ expr: E) throws -> Solution {
        let (ty, sub, names) = try expr.accept(visitor: &self)
        return Solution(type: ty, names: names, substitution: sub, tyVarLookup: tyVarLookup)
    }
}

extension TypeChecker: ExprVisitor {
    mutating func visit(_ expr: LiteralExpr) throws -> (Ty, Substitution, Names) {
        return switch expr.kind {
        case .numeric(_, let isInt): (isInt ? .integer : .real, [:], .none)
        case .string: (.text, [:], .none)
        case .blob: (.blob, [:], .none)
        case .null: (.any, [:], .none)
        case .true, .false: (.bool, [:], .none)
        case .currentTime, .currentDate, .currentTimestamp: (.text, [:], .none)
        }
    }
    
    mutating func visit(_ expr: BindParameter) throws -> (Ty, Substitution, Names) {
        let names: Names = switch expr.kind {
        case .named: .none
        case .unnamed(let index): .needed(index: index)
        }
        return (.var(freshTyVar(for: expr)), [:], names)
    }
    
    mutating func visit(_ expr: ColumnExpr) throws -> (Ty, Substitution, Names) {
        let result: Scope.ColumnResult = if let table = expr.table {
            scope.column(schema: expr.schema, table: table, name: expr.column)
        } else {
            scope.column(name: expr.column)
        }
        
        switch result {
        case .found(let column):
            return (.nominal(column.type), [:], .some(expr.column.name))
        case .ambiguous:
            diagnostics.add(.init(
                "Column '\(expr)' is ambiguous in the current context",
                at: expr.range,
                suggestion: "\(Diagnostic.placeholder(name: "tableName")).\(expr)"
            ))
            return (.error, [:], .some(expr.column.name))
        case .notFound:
            diagnostics.add(.init(
                "No such column '\(expr)' available in current context",
                at: expr.range
            ))
            return (.error, [:], .some(expr.column.name))
        }
    }
    
    mutating func visit(_ expr: PrefixExpr) throws -> (Ty, Substitution, Names) {
        if !expr.operator.operator.canBePrefix {
            diagnostics.add(.init("'\(expr.operator.operator)' is not a valid prefix operator", at: expr.operator.range))
        }
        
        return try expr.rhs.accept(visitor: &self)
    }
    
    mutating func visit(_ expr: InfixExpr) throws -> (Ty, Substitution, Names) {
        let (lTy, lSub, lNames) = try expr.lhs.accept(visitor: &self)
        let (rTy, rSub, rNames) = try expr.rhs.accept(visitor: &self)
        let names = lNames.merging(with: rNames)
        
        switch expr.operator.operator {
        // Arithmetic Operators
        case .plus, .minus, .multiply, .divide, .bitwuseOr,
                .bitwiseAnd, .shl, .shr, .mod:
            let (sub, ty) = lTy.unify(with: rTy)
            return (ty, lSub.merging(rSub, uniquingKeysWith: {$1}).merging(sub, uniquingKeysWith: {$1}), names)
        // Comparisons
        case .eq, .eq2, .neq, .neq2, .lt, .gt, .lte, .gte, .is,
                .notNull, .notnull, .in, .like, .isNot, .isDistinctFrom,
                .isNotDistinctFrom, .between, .and, .or, .isnull:
            let (sub, _) = lTy.unify(with: rTy)
            return (.bool, lSub.merging(rSub, uniquingKeysWith: {$1}).merging(sub, uniquingKeysWith: {$1}), names)

//        case .tilde: return .any
//        case .collate: return lhs
//        case .concat: return .text
//        case .arrow, .doubleArrow: return .any
//        case .escape: return lhs
//        case .match: return .any
//        case .regexp: return .any
//        case .glob: return .any
//        
//        case .not: return .any
        default:
            fatalError()
        }
    }
    
    mutating func visit(_ expr: PostfixExpr) throws -> (Ty, Substitution, Names) {
        return try expr.lhs.accept(visitor: &self)
    }
    
    mutating func visit(_ expr: BetweenExpr) throws -> (Ty, Substitution, Names) {
        fatalError()
//        let (vTy, vSub) = try expr.value.accept(visitor: &self)
//        let sub = vTy.unify(with: .bool)
        
//        if value != .bool {
//            diagnostics.add(.incorrectType(value, expected: .bool, at: expr.range))
//        }
//        
//        if try !expr.lower.accept(visitor: &self).isNumber {
//            diagnostics.add(.expectedNumber(value, at: expr.range))
//        }
//        
//        if try !expr.upper.accept(visitor: &self).isNumber {
//            diagnostics.add(.expectedNumber(value, at: expr.range))
//        }
//        
//        return .bool
    }
    
    mutating func visit(_ expr: FunctionExpr) throws -> (Ty, Substitution, Names) {
        fatalError()
    }
    
    mutating func visit(_ expr: CastExpr) throws -> (Ty, Substitution, Names) {
        fatalError()
    }
    
    mutating func visit(_ expr: Expression) throws -> (Ty, Substitution, Names) {
        fatalError()
    }
    
    mutating func visit(_ expr: CaseWhenThenExpr) throws -> (Ty, Substitution, Names) {
        fatalError()
    }
    
    mutating func visit(_ expr: GroupedExpr) throws -> (Ty, Substitution, Names) {
        fatalError()
    }
}
