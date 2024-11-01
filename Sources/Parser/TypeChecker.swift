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
    
    func function(name: Identifier) -> TypeScheme? {
        return Self.functions[name.name]
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
        case .fn: return .any // TODO: Error
        case .var: return .any
        case .error: return .any
        }
    }
    
    func name(for index: Int) -> Substring {
        return names.map[index] ?? "value"
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
    
    func merging(_ other: Substitution, and another: Substitution, and oneMore: Substitution) -> Substitution {
        var output = self
        for (k, v) in other { output[k] = v }
        for (k, v) in another { output[k] = v }
        for (k, v) in oneMore { output[k] = v }
        return output
    }
    
    func merging(all subs: [Substitution]) -> Substitution {
        var output = self
        for sub in subs {
            for (k, v) in sub { output[k] = v }
        }
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
        let (ty, sub, names) = try expr.accept(visitor: &self)
        return Solution(type: ty, names: names, substitution: sub, tyVarLookup: tyVarLookup)
    }
    
    /// Unifies the two types together. Will produce a substitution if one
    /// is a type variable. If there are two nominal types they and
    /// they can be coerced en empty substitution will be return with
    /// the coerced type.
    private mutating func unify(_ ty: Ty, with other: Ty, at range: Range<String.Index>) -> (Substitution, Ty) {
        // If they are the same, no need to unify
        guard ty != other else { return ([:], ty) }
        
        switch (ty, other) {
        case let (.var(t1), .var(t2)):
            return ([t2: .var(t1)], ty)
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
            // Due to ANY's ambiguity we cannot really check it
            // so just assume the caller expects an ANY as well.
            case (.any, _): return ([:], .any)
            case (_, .any): return ([:], .any)
            default:
                diagnostics.add(.init("Unable to unify types '\(ty)' and '\(other)'", at: range))
                return ([:], .any)
            }
        case let (.error, ty):
            return ([:], ty)
        case let (ty, .error):
            return ([:], ty)
        default:
            diagnostics.add(.init("Unable to unify types '\(ty)' and '\(other)'", at: range))
            return ([:], .error)
        }
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
            diagnostics.add(.init(
                "'\(expr.operator.operator)' is not a valid prefix operator",
                at: expr.operator.range
            ))
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
            let (sub, ty) = unify(lTy, with: rTy, at: expr.range)
            let (sub2, ty2) = unify(ty, with: .integer, at: expr.range)
            return (ty2, lSub.merging(rSub, and: sub, and: sub2), names)
        // Comparisons
        case .eq, .eq2, .neq, .neq2, .lt, .gt, .lte, .gte, .is,
                .notNull, .notnull, .in, .like, .isNot, .isDistinctFrom,
                .isNotDistinctFrom, .between, .and, .or, .isnull:
            let (sub, _) = unify(lTy, with: rTy, at: expr.range)
            return (.bool, lSub.merging(rSub, and: sub), names)

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
        let (vTy, vSub, vNames) = try expr.value.accept(visitor: &self)
        let (lTy, lSub, lNames) = try expr.lower.accept(visitor: &self)
        let (rTy, rSub, rNames) = try expr.upper.accept(visitor: &self)
        let (s, t1) = unify(vTy, with: lTy, at: expr.range)
        let (s2, t2) = unify(lTy, with: t1, at: expr.range)
        let (s3, _) = unify(rTy, with: t2, at: expr.range)
        return (
            .bool,
            vSub.merging(lSub, and: rSub, and: s).merging(s, and: s2, and: s3),
            vNames.merging(with: lNames).merging(with: rNames)
        )
    }
    
    mutating func visit(_ expr: FunctionExpr) throws -> (Ty, Substitution, Names) {
        let args = try expr.args.map { try $0.accept(visitor: &self) }
        
        guard let scheme = scope.function(name: expr.name) else {
            diagnostics.add(.init("No such function '\(expr.name)' exits", at: expr.range))
            return (.any, [:], .none)
        }
        
        guard case let .fn(params, variadic, ret) = instantiate(scheme) else {
            diagnostics.add(.init("'\(expr.name)' is not a function", at: expr.range))
            return (.any, [:], .none)
        }
        
        let (ty, sub) = try infer(
            args: args.map(\.0),
            params: params,
            variadic: variadic,
            ret: ret,
            at: expr.range
        )
        
        return (ty, args.reduce(into: [:], { $0.merge($1.1, uniquingKeysWith: {$1}) }).merging(sub), .none)
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
    
    private mutating func infer(
        args: [Ty],
        params: [Ty],
        variadic: Bool,
        ret: Ty,
        at range: Range<String.Index>
    ) throws -> (Ty, Substitution) {
        if !variadic, args.count != params.count {
            diagnostics.add(.init(
                "Incorrect number of arguments, got '\(args.count)' expected '\(params.count)'",
                at: range
            ))
        }
        
        if variadic, args.count < params.count {
            diagnostics.add(.init(
                "Incorrect number of arguments, got '\(args.count)' expected '\(params.count)' or more",
                at: range
            ))
        }
        
        var args = args.makeIterator()
        guard var arg = args.next() else {
            // A previous diagnostic will have displayed an error, so no need to repeat
            return (ret, [:])
        }
        
        var sub: Substitution = [:]
        
        for (index, param) in params.enumerated() {
            let isLast = params.count - 1 == index
            
            if isLast {
                var argTy = arg
                var argSub: Substitution = [:]
                
                // For the final parameter we first want to unify all of the arguments
                // for the final param to handle the variadics before unifying it
                // with the actual parameter type.
                //
                // This feels very wrong but I'm not sure of a better way atm.
                // TODO: Revisit this.
                while let arg = args.next() {
                    let (s, newTy) = unify(argTy, with: arg, at: range)
                    argTy = newTy
                    argSub.merge(s, uniquingKeysWith: {$1})
                }
                
                let (finalSub, _) = unify(argTy, with: param, at: range)
                sub.merge(argSub, uniquingKeysWith: {$1})
                sub.merge(finalSub, uniquingKeysWith: {$1})
            } else if let next = args.next() {
                let (s, _) = unify(param, with: arg, at: range)
                sub.merge(s, uniquingKeysWith: {$1})
                arg = next
            } else {
                return (ret, sub)
            }
        }
        
        return (ret.apply(sub), sub)
    }
}


enum Constraint {
    case equal(Ty, Ty)
    case conforms(Ty, TypeConstraints)
}

extension TypeChecker {
    mutating func solve(constraints: [Constraint]) {
        var solution: Substitution = [:]
        var conformances: [(Ty, TypeConstraints)] = []
        
        for constraint in constraints {
            switch constraint {
            case .equal(let ty, let ty2):
                let (s, t) = unify(ty, with: ty2, at: "".startIndex..<"".endIndex)
                solution.merge(s, uniquingKeysWith: {$1})
            case .conforms(let ty, let typeConstraints):
                conformances.append((ty, typeConstraints))
            }
        }
        
        for (ty, constraint) in conformances {
            let ty = ty.apply(solution)
            
            switch ty {
            case .nominal(let typeName):
                if constraint.contains(.numeric), (ty != .integer || ty != .real) {
                    fatalError("TODO: Throw real error")
                }
            case .var(let typeVariable):
                // TODO: Actually default
                solution[typeVariable] = .integer
            case .fn:
                fatalError("TODO: Throw real error")
            case .error:
                fatalError("TODO: Throw real error")
            }
        }
    }
}

struct Solution2 {
    var type: Ty
    var names: Names
    var substitution: Substitution
    var constraints: [(TypeVariable, TypeConstraints)]
    private var tyVarLookup: [BindParameter.Kind: TypeVariable]
    
    func merging(with other: Solution2) -> Solution2 {
        return Solution2(
            type: other.type,
            names: names.merging(with: other.names),
            substitution: substitution.merging(other.substitution),
            constraints: constraints + other.constraints,
            tyVarLookup: tyVarLookup.merging(other.tyVarLookup, uniquingKeysWith: {$1})
        )
    }
}
