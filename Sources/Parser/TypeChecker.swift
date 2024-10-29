//
//  TypeChecker.swift
//
//
//  Created by Wes Wickwire on 10/19/24.
//

import OrderedCollections
import Schema

public struct Scope {
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
                if result == .notFound {
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

public struct CompiledQuery {
    public let input: [Field<BindParameter>]
    public let output: [Field<Substring>]
    
    public struct Field<Name> {
        public let name: Name
        public let type: TypeName
        public let nullable: Bool
        
        public init(name: Name, type: TypeName, nullable: Bool) {
            self.name = name
            self.type = type
            self.nullable = nullable
        }
    }
}

struct Solution {
    let type: Ty
    let substitution: Substitution
    let tyVarLookup: [BindParameter.Kind: TypeVariable]
    
    func type(for param: BindParameter.Kind) -> TypeName {
        guard let tv = tyVarLookup[param] else { fatalError("TODO: Throw real error") }
        
        // TODO: More errors and diag
        switch Ty.var(tv).apply(substitution) {
        case .nominal(let t): return t
        case .var: return .any
        case .error: return .any
        }
    }
}

public struct TypeChecker {
    private let scope: Scope
    private var diagnostics: Diagnostics
    private var tyVars = 0
    var tyVarLookup: [BindParameter.Kind: TypeVariable] = [:]
    
    public init(scope: Scope, diagnostics: Diagnostics = Diagnostics()) {
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
        let (ty, sub) = try expr.accept(visitor: &self)
        return Solution(type: ty, substitution: sub, tyVarLookup: tyVarLookup)
    }
}

public struct TypeVariable: Hashable, CustomStringConvertible {
    public let n: Int
    
    init(_ n: Int) {
        self.n = n
    }
    
    public var description: String {
        return "τ\(n)"
    }
}

public enum Constraint {
    case equal(Ty, Ty)
    case numeric(Ty)
}

public typealias Substitution = [TypeVariable: Ty]
public typealias Names = [Int: Substring]

public enum Ty: Equatable, CustomStringConvertible {
    case nominal(TypeName)
    case `var`(TypeVariable)
    case error
    
    public static let text: Ty = .nominal(TypeName(name: "TEXT", args: nil, resolved: .text))
    public static let int: Ty = .nominal(TypeName(name: "INT", args: nil, resolved: .int))
    public static let integer: Ty = .nominal(TypeName(name: "INTEGER", args: nil, resolved: .integer))
    public static let real: Ty = .nominal(TypeName(name: "REAL", args: nil, resolved: .real))
    public static let blob: Ty = .nominal(TypeName(name: "BLOB", args: nil, resolved: .blob))
    public static let any: Ty = .nominal(TypeName(name: "ANY", args: nil, resolved: .any))
    public static let bool: Ty = .nominal(TypeName(name: "BOOL", args: nil, resolved: .int))
    
    public var description: String {
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

extension TypeChecker: ExprVisitor {
    public mutating func visit(_ expr: LiteralExpr) throws -> (Ty, Substitution) {
        return switch expr.kind {
        case .numeric(_, let isInt): (isInt ? .integer : .real, [:])
        case .string: (.text, [:])
        case .blob: (.blob, [:])
        case .null: (.any, [:])
        case .true, .false: (.bool, [:])
        case .currentTime, .currentDate, .currentTimestamp: (.text, [:])
        }
    }
    
    public mutating func visit(_ expr: BindParameter) throws -> (Ty, Substitution) {
        return (.var(freshTyVar(for: expr)), [:])
    }
    
    public mutating func visit(_ expr: ColumnExpr) throws -> (Ty, Substitution) {
        let result: Scope.ColumnResult = if let table = expr.table {
            scope.column(schema: expr.schema, table: table, name: expr.column)
        } else {
            scope.column(name: expr.column)
        }
        
        switch result {
        case .found(let column):
            return (.nominal(column.type), [:])
        case .ambiguous:
            diagnostics.add(.init(
                "Column '\(expr)' is ambiguous in the current context",
                at: expr.range,
                suggestion: "\(Diagnostic.placeholder(name: "tableName")).\(expr)"
            ))
            return (.error, [:])
        case .notFound:
            diagnostics.add(.init(
                "No such column '\(expr)' available in current context",
                at: expr.range
            ))
            return (.error, [:])
        }
    }
    
    public mutating func visit(_ expr: PrefixExpr) throws -> (Ty, Substitution) {
        return try expr.rhs.accept(visitor: &self)
    }
    
    public mutating func visit(_ expr: InfixExpr) throws -> (Ty, Substitution) {
        let (lTy, lSub) = try expr.lhs.accept(visitor: &self)
        let (rTy, rSub) = try expr.rhs.accept(visitor: &self)
        
        switch expr.operator.operator {
        // Arithmetic Operators
        case .plus, .minus, .multiply, .divide, .bitwuseOr,
                .bitwiseAnd, .shl, .shr, .mod:
            let (sub, ty) = lTy.unify(with: rTy)
            return (ty, lSub.merging(rSub, uniquingKeysWith: {$1}).merging(sub, uniquingKeysWith: {$1}))
        // Comparisons
        case .eq, .eq2, .neq, .neq2, .lt, .gt, .lte, .gte, .is,
                .notNull, .notnull, .in, .like, .isNot, .isDistinctFrom,
                .isNotDistinctFrom, .between, .and, .or, .isnull:
            let (sub, _) = lTy.unify(with: rTy)
            return (.bool, lSub.merging(rSub, uniquingKeysWith: {$1}).merging(sub, uniquingKeysWith: {$1}))

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
    
    public mutating func visit(_ expr: PostfixExpr) throws -> (Ty, Substitution) {
        return try expr.lhs.accept(visitor: &self)
    }
    
    public mutating func visit(_ expr: BetweenExpr) throws -> (Ty, Substitution) {
        fatalError()
//        let value = try expr.value.accept(visitor: &self)
//        
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
    
    public mutating func visit(_ expr: FunctionExpr) throws -> (Ty, Substitution) {
        fatalError()
    }
    
    public mutating func visit(_ expr: CastExpr) throws -> (Ty, Substitution) {
        fatalError()
    }
    
    public mutating func visit(_ expr: Expression) throws -> (Ty, Substitution) {
        fatalError()
    }
    
    public mutating func visit(_ expr: CaseWhenThenExpr) throws -> (Ty, Substitution) {
        fatalError()
    }
    
    public mutating func visit(_ expr: GroupedExpr) throws -> (Ty, Substitution) {
        fatalError()
    }
}
