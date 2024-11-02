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
    
    static let max = TypeScheme(typeVariables: [0], type: .fn(params: [.var(0)], variadic: true, ret: .var(0)))
    static let between = TypeScheme(typeVariables: [0], type: .fn(params: [.var(0), .var(0), .var(0)], variadic: false, ret: .bool))
    static let arithmetic = TypeScheme(typeVariables: [0], type: .fn(params: [.var(0), .var(0)], variadic: false, ret: .var(0)))
    static let comparison = TypeScheme(typeVariables: [0], type: .fn(params: [.var(0), .var(0)], variadic: false, ret: .bool))
    
    static let functions: [Substring: TypeScheme] = [
        "MAX": max
    ]
    
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
    
    func function(name: Identifier, argCount: Int) -> TypeScheme? {
        guard let scheme = Self.functions[name.name],
                case let .fn(params, variadic, ret) = scheme.type else { return nil }
        
        // This is how variadics are handled. If a variadic function is called
        // we extend the signature to match the input count. It is always
        // assumed the last parameter is the variadic.
        let numberOfArgsToAdd = argCount - params.count
        
        guard variadic, argCount > 0, let last = params.last else { return scheme }
        
        return TypeScheme(
            typeVariables: scheme.typeVariables,
            type: .fn(
                params: params + (0..<numberOfArgsToAdd).map { _ in last },
                variadic: false,
                ret: ret
            )
        )
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

struct Solution: CustomStringConvertible {
    private let resultType: Ty
    private let names: Names
    private let substitution: Substitution
    private let contraints: [TypeVariable: TypeConstraints]
    private let tyVarLookup: [BindParameter.Kind: TypeVariable]
    private var valueNameCount = 0
    
    init(
        resultType: Ty,
        names: Names,
        substitution: Substitution,
        constraints: [TypeVariable: TypeConstraints],
        tyVarLookup: [BindParameter.Kind : TypeVariable]
    ) {
        self.resultType = resultType
        self.names = names
        self.substitution = substitution
        self.tyVarLookup = tyVarLookup
        self.contraints = constraints
    }
    
    var type: TypeName {
        return typeName(for: resultType)
    }
    
    var description: String {
        return "\(substitution.map { "\($0) ~> \($1)" }.joined(separator: "\n"))"
    }
    
    func type(for param: BindParameter.Kind) -> TypeName {
        guard let tv = tyVarLookup[param] else { fatalError("TODO: Throw real error") }
        return typeName(for: .var(tv))
    }
    
    mutating func name(for index: Int) -> Substring {
        if let name = names.map[index] { return name }
        defer { valueNameCount += 1 }
        return "value\(valueNameCount == 0 ? "" : "\(valueNameCount)")"
    }
    
    private func typeName(for ty: Ty) -> TypeName {
        switch ty.apply(substitution) {
        case .nominal(let t): return t
        case .fn: return .any // TODO: Error
        case .var(let tv):
            // The type variable was never bound to a concrete type.
            // Check if the constraints gives any clues about a default type
            // if none just assume `ANY`
            if let constraints = self.contraints[tv], constraints.contains(.numeric) {
                return .integer
            }
            return .any
        case .error: return .any
        }
    }
}

/// Any type constraints that may exist on the type variable.
/// SQL is not a full language and users cannot create their
/// own interfaces so a simple option set will do since it is
/// a finite number.
struct TypeConstraints: OptionSet, Hashable {
    let rawValue: UInt8
    
    static let numeric = TypeConstraints(rawValue: 1 << 0)
}



struct TypeVariable: Hashable, CustomStringConvertible, ExpressibleByIntegerLiteral {
    let n: Int
    
    
    init(_ n: Int) {
        self.n = n
    }
    
    init(integerLiteral value: Int) {
        self.n = value
    }
    
    var description: String {
        return "τ\(n)"
    }
}

struct TypeScheme: CustomStringConvertible {
    let typeVariables: [TypeVariable]
    let type: Ty
    
    var description : String {
        return "∀\(typeVariables.map(\.description).joined(separator: ", ")).\(self.type)"
    }
}

typealias Substitution = [TypeVariable: Ty]
typealias Constraints = [TypeVariable: TypeConstraints]

extension Constraints {
    func merging(_ other: Constraints) -> Constraints {
        return merging(other, uniquingKeysWith: { $0.union($1) })
    }
}

extension Substitution {
    func merging(_ other: Substitution) -> Substitution {
        guard !other.isEmpty else { return self }
        return merging(other, uniquingKeysWith: {$1})
    }
    
    func merging(_ other: Substitution, and another: Substitution) -> Substitution {
        var output = self
        for (k, v) in other { output[k] = v }
        for (k, v) in another { output[k] = v }
        return output
    }
}

enum Ty: Equatable, CustomStringConvertible {
    /// A builtin nominal type from the db (INTEGER, REAL...)
    case nominal(TypeName)
    /// A type variable
    case `var`(TypeVariable)
    /// A function.
    /// If `variadic` is `true`, it assumes it is over the last type in the arguments.
    indirect case fn(params: [Ty], variadic: Bool, ret: Ty)
    /// There was an error somewhere in the analysis. We can just return
    /// an `error` type and continue the analysis. So if the user makes up
    /// 3 columns, they can get all 3 errors at once.
    ///
    /// We could just return `ANY` but an explicit `error` type lets the
    /// type unification be more precise since we know the `error` type
    /// is incorrect the type its being unified with can be prioritized.
    /// Example:
    /// `ANY + INTEGER = ANY` - Bad
    /// `error + INTEGER = INTEGER` - Good
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
        case let .fn(args, variadic, ret): "(\(args.map(\.description).joined(separator: ","))\(variadic ? "..." : "")) -> \(ret)"
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
        case let .fn(params, variadic, ret):
            return .fn(
                params: params.map{ $0.apply(s) },
                variadic: variadic,
                ret: ret.apply(s)
            )
        case .nominal, .error:
            // Literals can't be substituted for.
            return self
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
    
    enum Context {
        case lower
        case upper
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
        case (.none, _):
            return other
        case (_, .none):
            return self
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
    
    func dumpDiagnostics(in source: String) {
        for diagnostic in diagnostics.diagnostics {
            print(diagnostic.message, "   Expression:", source[diagnostic.range])
        }
    }
    
    private mutating func freshTyVar(for param: BindParameter? = nil) -> TypeVariable {
        defer { tyVars += 1 }
        let ty = TypeVariable(tyVars)
        if let param {
            tyVarLookup[param.kind] = ty
        }
        return ty
    }
    
    private mutating func instantiate(_ typeScheme: TypeScheme) -> Ty {
        let sub = Substitution(typeScheme.typeVariables.map { ($0, .var(freshTyVar())) }, uniquingKeysWith: {$1})
        return typeScheme.type.apply(sub)
    }
    
    mutating func check<E: Expr>(_ expr: E) throws -> Solution {
        let (ty, sub, con, names) = try expr.accept(visitor: &self)
        
        let result = ty.apply(sub)
        let resultCon = finalize(constraints: con, with: sub)
        
        return Solution(
            resultType: result,
            names: names,
            substitution: sub,
            constraints: resultCon,
            tyVarLookup: tyVarLookup
        )
    }
    
    private mutating func finalize(
        constraints: Constraints,
        with substitution: Substitution
    ) -> Constraints {
        var result: [TypeVariable: TypeConstraints] = [:]
        
        for (tv, constraints) in constraints {
            let ty = Ty.var(tv).apply(substitution)
            
            if case let .var(tv) = ty {
                result[tv] = constraints
            } else {
                // TODO: If it is a non type variable we need to validate
                // the type meets the constraints requirements.
            }
        }
        
        return result
    }
    
    /// Unifies the two types together. Will produce a substitution if one
    /// is a type variable. If there are two nominal types they and
    /// they can be coerced en empty substitution will be return with
    /// the coerced type.
    private mutating func unify(
        _ ty: Ty,
        with other: Ty,
        at range: Range<String.Index>
    ) -> Substitution {
        // If they are the same, no need to unify
        guard ty != other else { return [:] }
        
        switch (ty, other) {
        case let (.var(tv), ty):
            return [tv: ty]
        case let (ty, .var(tv)):
            return [tv: ty]
        case let (.nominal(t1), .nominal(t2)):
            guard t1 != t2 else { return [:] }
            
            switch (t1, t2) {
            case (.integer, .real):
                return [:]
            case (.real, .integer):
                return [:]
            default:
                diagnostics.add(.init("Unable to unify types '\(ty)' and '\(other)'", at: range))
            }
            return [:]
        case let (.fn(args1, _, ret1), .fn(args2, _, ret2)):
            let args = unify(args1, with: args2, at: range)
            let ret = unify(ret1.apply(args), with: ret2.apply(args), at: range)
            return ret.merging(args)
        case (.error, _), (_, .error):
            // Already had an upstream error so no need to emit any more diagnostics
            return [:]
        default:
            diagnostics.add(.init("Unable to unify types '\(ty)' and '\(other)'", at: range))
            return [:]
        }
    }
    
    private mutating func unify(
        _ tys: [Ty],
        with others: [Ty],
        at range: Range<String.Index>
    ) -> Substitution {
        assert(tys.count == others.count)
        
        var sub: Substitution = [:]
        var tys = tys.makeIterator()
        var others = others.makeIterator()
        
        while let ty1 = tys.next(), let ty2 = others.next() {
            sub.merge(unify(ty1.apply(sub), with: ty2.apply(sub), at: range), uniquingKeysWith: {$1})
        }
        
        return sub
    }
}

extension TypeChecker: ExprVisitor {
    mutating func visit(_ expr: LiteralExpr) throws -> (Ty, Substitution, Constraints, Names) {
        switch expr.kind {
        case .numeric(_, let isInt):
            if isInt {
                let tv = freshTyVar()
                return (.var(tv), [:], [tv: .numeric], .none)
            } else {
                return (.real, [:], [:], .none)
            }
        case .string: return (.text, [:], [:], .none)
        case .blob: return (.blob, [:], [:], .none)
        case .null: return (.any, [:], [:], .none)
        case .true, .false: return (.bool, [:], [:], .none)
        case .currentTime, .currentDate, .currentTimestamp: return (.text, [:], [:], .none)
        }
    }
    
    mutating func visit(_ expr: BindParameter) throws -> (Ty, Substitution, Constraints, Names) {
        let names: Names = switch expr.kind {
        case .named: .none
        case .unnamed(let index): .needed(index: index)
        }
        return (.var(freshTyVar(for: expr)), [:], [:], names)
    }
    
    mutating func visit(_ expr: ColumnExpr) throws -> (Ty, Substitution, Constraints, Names) {
        let result: Scope.ColumnResult = if let table = expr.table {
            scope.column(schema: expr.schema, table: table, name: expr.column)
        } else {
            scope.column(name: expr.column)
        }
        
        switch result {
        case .found(let column):
            return (.nominal(column.type), [:], [:], .some(expr.column.name))
        case .ambiguous:
            diagnostics.add(.init(
                "Column '\(expr)' is ambiguous in the current context",
                at: expr.range,
                suggestion: "\(Diagnostic.placeholder(name: "tableName")).\(expr)"
            ))
            return (.error, [:], [:], .some(expr.column.name))
        case .notFound:
            diagnostics.add(.init(
                "No such column '\(expr)' available in current context",
                at: expr.range
            ))
            return (.error, [:], [:], .some(expr.column.name))
        }
    }
    
    mutating func visit(_ expr: PrefixExpr) throws -> (Ty, Substitution, Constraints, Names) {
        if !expr.operator.operator.canBePrefix {
            diagnostics.add(.init(
                "'\(expr.operator.operator)' is not a valid prefix operator",
                at: expr.operator.range
            ))
        }
        
        return try expr.rhs.accept(visitor: &self)
    }
    
    mutating func visit(_ expr: InfixExpr) throws -> (Ty, Substitution, Constraints, Names) {
        let (lTy, lSub, lCon, lNames) = try expr.lhs.accept(visitor: &self)
        let (rTy, rSub, rCon, rNames) = try expr.rhs.accept(visitor: &self)
        let names = lNames.merging(with: rNames)
        
        switch expr.operator.operator {
        // Arithmetic Operators
        case .plus, .minus, .multiply, .divide, .bitwuseOr,
                .bitwiseAnd, .shl, .shr, .mod:
            let tv: Ty = .var(freshTyVar())
            let fnType = instantiate(Scope.arithmetic)
            let sub = unify(fnType, with: .fn(params: [lTy.apply(rSub), rTy], variadic: false, ret: tv), at: expr.range)
            return (tv.apply(sub), sub.merging(rSub, and: lSub), lCon.merging(rCon), names)
        // Comparisons
        case .eq, .eq2, .neq, .neq2, .lt, .gt, .lte, .gte, .is,
                .notNull, .notnull, .in, .like, .isNot, .isDistinctFrom,
                .isNotDistinctFrom, .between, .and, .or, .isnull:
            let fnType = instantiate(Scope.comparison)
            let sub = unify(fnType, with: .fn(params: [lTy.apply(rSub), rTy], variadic: false, ret: .bool), at: expr.range)
            return (.bool, sub.merging(rSub, and: lSub), lCon.merging(rCon), names)

//        case .tilde: return .any
//        case .collate: return lhs
//        case .concat: return .text
//        case .arrow, .doubleArrow: return .any
//        case .escape: return lhs
//        case .match: return .any
//        case .regexp: return .any
//        case .glob: return .any
//        case .not: return .any
        default:
            fatalError()
        }
    }
    
    mutating func visit(_ expr: PostfixExpr) throws -> (Ty, Substitution, Constraints, Names) {
        return try expr.lhs.accept(visitor: &self)
    }
    
    mutating func visit(_ expr: BetweenExpr) throws -> (Ty, Substitution, Constraints, Names) {
        let (tys, sub, con, names) = try visit(many: [expr.value, expr.lower, expr.upper])
        let betSub = unify(instantiate(Scope.between), with: .fn(params: tys, variadic: false, ret: .bool), at: expr.range)
        return (.bool, betSub.merging(sub), con, names)
    }
    
    mutating func visit(_ expr: FunctionExpr) throws -> (Ty, Substitution, Constraints, Names) {
        let (argTys, argSub, argConstraints, argNames) = try visit(many: expr.args)
        
        guard let scheme = scope.function(name: expr.name, argCount: argTys.count) else {
            diagnostics.add(.init("No such function '\(expr.name)' exits", at: expr.range))
            return (.error, argSub, argConstraints, argNames)
        }
        
        let tv: Ty = .var(freshTyVar())
        let sub = unify(instantiate(scheme), with: .fn(params: argTys, variadic: false, ret: tv), at: expr.range)
        return (tv, sub.merging(argSub), argConstraints, argNames)
    }
    
    mutating func visit(_ expr: CastExpr) throws -> (Ty, Substitution, Constraints, Names) {
        fatalError()
    }
    
    mutating func visit(_ expr: Expression) throws -> (Ty, Substitution, Constraints, Names) {
        fatalError()
    }
    
    mutating func visit(_ expr: CaseWhenThenExpr) throws -> (Ty, Substitution, Constraints, Names) {
        fatalError()
    }
    
    mutating func visit(_ expr: GroupedExpr) throws -> (Ty, Substitution, Constraints, Names) {
        fatalError()
    }
    
    mutating func visit(many exprs: [Expression]) throws -> ([Ty], Substitution, Constraints, Names) {
        var tys: [Ty] = []
        var sub: Substitution = [:]
        var constraints: [TypeVariable: TypeConstraints] = [:]
        var names: Names = .none
        
        for expr in exprs {
            let (t, s, c, n) = try expr.accept(visitor: &self)
            tys.append(t.apply(sub))
            sub.merge(s, uniquingKeysWith: {$1})
            constraints.merge(c, uniquingKeysWith: { $0.union($1) })
            names = names.merging(with: n)
        }
        
        return (tys, sub, constraints, names)
    }
}
