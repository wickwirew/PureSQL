//
//  TypeChecker.swift
//
//
//  Created by Wes Wickwire on 10/19/24.
//

import OrderedCollections
import Schema

struct Solution: CustomStringConvertible {
    let diagnostics: Diagnostics
    private let resultType: Ty
    private let names: Names
    private let substitution: Substitution
    private let contraints: [TypeVariable: TypeConstraints]
    private let tyVarLookup: [BindParameter.Kind: TypeVariable]
    private var valueNameCount = 0
    
    init(
        diagnostics: Diagnostics,
        resultType: Ty,
        names: Names,
        substitution: Substitution,
        constraints: [TypeVariable: TypeConstraints],
        tyVarLookup: [BindParameter.Kind : TypeVariable]
    ) {
        self.diagnostics = diagnostics
        self.resultType = resultType
        self.names = names
        self.substitution = substitution
        self.tyVarLookup = tyVarLookup
        self.contraints = constraints
    }
    
    var type: Ty {
        return type(for: resultType)
    }
    
    var lastName: Substring? {
        return names.lastName
    }
    
    var description: String {
        return "\(substitution.map { "\($0) ~> \($1)" }.joined(separator: "\n"))"
    }
    
    var allNames: [(Substring, Ty)] {
        mutating get {
            tyVarLookup.map { kind, tv in
                switch kind {
                case .named(let name):
                    return (name.value, type(for: .var(tv)))
                case .unnamed(let index):
                    return (name(for: index), type(for: .var(tv)))
                }
            }
        }
    }
    
    func type(for param: BindParameter.Kind) -> Ty {
        guard let tv = tyVarLookup[param] else { fatalError("TODO: Throw real error") }
        return type(for: .var(tv))
    }
    
    mutating func name(for index: Int) -> Substring {
        if let name = names.map[index] { return name }
        defer { valueNameCount += 1 }
        return "value\(valueNameCount == 0 ? "" : "\(valueNameCount)")"
    }
    
    private func type(for ty: Ty) -> Ty {
        let ty = ty.apply(substitution)
        
        switch ty.apply(substitution) {
        case .var(let tv):
            // The type variable was never bound to a concrete type.
            // Check if the constraints gives any clues about a default type
            // if none just assume `ANY`
            if let constraints = self.contraints[tv], constraints.contains(.numeric) {
                return .integer
            }
            return .any
        case .row(let tys):
            // TODO: Clean this up
            return .row(.unnamed(tys.types.map { type(for: $0) }))
        default:
            return ty
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
    
    func merging(_ a: Substitution, _ b: Substitution) -> Substitution {
        var output = self
        for (k, v) in a { output[k] = v }
        for (k, v) in b { output[k] = v }
        return output
    }
    
    func merging(_ a: Substitution, _ b: Substitution, _ c: Substitution) -> Substitution {
        var output = self
        for (k, v) in a { output[k] = v }
        for (k, v) in b { output[k] = v }
        for (k, v) in c { output[k] = v }
        return output
    }
    
    func merging(_ a: Substitution, _ b: Substitution, _ c: Substitution, _ d: Substitution) -> Substitution {
        var output = self
        for (k, v) in a { output[k] = v }
        for (k, v) in b { output[k] = v }
        for (k, v) in c { output[k] = v }
        for (k, v) in d { output[k] = v }
        return output
    }
    
    func merging(_ a: Substitution, _ b: Substitution, _ c: Substitution, _ d: Substitution, _ e: Substitution) -> Substitution {
        var output = self
        for (k, v) in a { output[k] = v }
        for (k, v) in b { output[k] = v }
        for (k, v) in c { output[k] = v }
        for (k, v) in d { output[k] = v }
        for (k, v) in e { output[k] = v }
        return output
    }
}

enum Ty: Equatable, CustomStringConvertible, Sendable {
    /// A builtin nominal type from the db (INTEGER, REAL...)
    case nominal(Substring)
    /// A type variable
    case `var`(TypeVariable)
    /// A function.
    /// If `variadic` is `true`, it assumes it is over the last type in the arguments.
    indirect case fn(params: [Ty], ret: Ty)
    /// A row. This can be a list of values in parenthesis
    /// or even a single value.
    case row(RowTy)
    indirect case optional(Ty)
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
    
    enum RowTy: Equatable, Sendable, ExpressibleByArrayLiteral {
        case named(OrderedDictionary<Substring, Ty>)
        case unnamed([Ty])
        
        init(arrayLiteral elements: Ty...) {
            self = .unnamed(elements)
        }
        
        var first: Ty? {
            return switch self {
            case .named(let v): v.values.first
            case .unnamed(let v): v.first
            }
        }
        
        var count: Int {
            return switch self {
            case .named(let v): v.count
            case .unnamed(let v): v.count
            }
        }
        
        var types: [Ty] {
            return switch self {
            case .named(let v): Array(v.values)
            case .unnamed(let v): v
            }
        }
        
        func apply(_ s: Substitution) -> RowTy {
            return switch self {
            case .named(let v): .named(v.mapValues { $0.apply(s) })
            case .unnamed(let v): .unnamed(v.map { $0.apply(s) })
            }
        }
    }
    
    static let text: Ty = .nominal("TEXT")
    static let int: Ty = .nominal("INT")
    static let integer: Ty = .nominal("INTEGER")
    static let real: Ty = .nominal("REAL")
    static let blob: Ty = .nominal("BLOB")
    static let any: Ty = .nominal("ANY")
    static let bool: Ty = .nominal("BOOL")
    
    var description: String {
        return switch self {
        case .nominal(let typeName): typeName.description
        case .var(let typeVariable): typeVariable.description
        case let .fn(args, ret): "(\(args.map(\.description).joined(separator: ","))) -> \(ret)"
        case let .row(row): switch row {
        case .named(let values): "(\(values.map{ "\($0):\($1)" }.joined(separator: ",")))"
        case .unnamed(let values): "(\(values.map(\.description).joined(separator: ",")))"
        }
        case let .optional(ty): "\(ty)?"
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
        case let .fn(params, ret):
            return .fn(
                params: params.map{ $0.apply(s) },
                ret: ret.apply(s)
            )
        case let .row(tys):
            return .row(tys.apply(s))
        case let .optional(ty):
            return .optional(ty)
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
    
    var lastName: Substring? {
        if case let .some(s) = last { return s }
        return nil
    }
    
    func merging(_ other: Names) -> Names {
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
    private let env: Environment
    private var diagnostics: Diagnostics
    private var tyVars = 0
    private var tyVarLookup: [BindParameter.Kind: TypeVariable] = [:]
    private var names: [Int: Substring] = [:]
    
    init(env: Environment, diagnostics: Diagnostics = Diagnostics()) {
        self.env = env
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
        guard !typeScheme.typeVariables.isEmpty else { return typeScheme.type }
        let sub = Substitution(typeScheme.typeVariables.map { ($0, .var(freshTyVar())) }, uniquingKeysWith: {$1})
        return typeScheme.type.apply(sub)
    }
    
    mutating func check<E: Expr>(_ expr: E) throws -> Solution {
        let (ty, sub, con, names) = expr.accept(visitor: &self)
        
        let result = ty.apply(sub)
        let resultCon = finalize(constraints: con, with: sub)
        
        return Solution(
            diagnostics: diagnostics,
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
        case (.integer, .real):
            return [:]
        case (.real, .integer):
            return [:]
        case (.nominal, .nominal):
            guard ty != other else { return [:] }
            diagnostics.add(.init("Unable to unify types '\(ty)' and '\(other)'", at: range))
            return [:]
        case let (.optional(t1), t2):
            return unify(t1, with: t2, at: range)
        case let (t1, .optional(t2)):
            return unify(t1, with: t2, at: range)
        case let (.fn(args1, ret1), .fn(args2, ret2)):
            let args = unify(args1, with: args2, at: range)
            let ret = unify(ret1.apply(args), with: ret2.apply(args), at: range)
            return ret.merging(args)
        case let (.row(row), t):
            if row.count == 1, let first = row.first {
                return unify(first, with: t, at: range)
            } else {
                diagnostics.add(.init("Unable to unify types '\(ty)' and '\(other)'", at: range))
                return [:]
            }
        case let (t, .row(row)):
            if row.count == 1, let first = row.first {
                return unify(first, with: t, at: range)
            } else {
                diagnostics.add(.init("Unable to unify types '\(ty)' and '\(other)'", at: range))
                return [:]
            }
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
    
    private mutating func unify(
        all tys: [Ty],
        at range: Range<String.Index>
    ) -> Substitution {
        var tys = tys.makeIterator()
        var sub: Substitution = [:]
        
        guard var lastTy = tys.next() else { return sub }

        while let ty = tys.next() {
            sub.merge(unify(lastTy, with: ty.apply(sub), at: range), uniquingKeysWith: {$1})
            lastTy = ty
        }
        
        return sub
    }
}

extension TypeChecker: ExprVisitor {
    mutating func visit(_ expr: borrowing LiteralExpr) -> (Ty, Substitution, Constraints, Names) {
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
    
    mutating func visit(_ expr: borrowing BindParameter) -> (Ty, Substitution, Constraints, Names) {
        // This is the only expr that needs to be consumed. We hold on to these
        // to keep track of naming and type info.
        let expr = copy expr
        let names: Names = switch expr.kind {
        case .named: .none
        case .unnamed(let index): .needed(index: index)
        }
        return (.var(freshTyVar(for: expr)), [:], [:], names)
    }
    
    mutating func visit(_ expr: borrowing ColumnExpr) -> (Ty, Substitution, Constraints, Names) {
        if let tableName = expr.table {
            guard let scheme = env[tableName.value] else {
                diagnostics.add(.init(
                    "Table named '\(expr)' does not exist",
                    at: expr.range
                ))
                return (.error, [:], [:], .some(expr.column.value))
            }
            
            // TODO: Maybe put this in the scheme instantiation?
            if scheme.isAmbiguous {
                diagnostics.add(.ambiguous(tableName.value, at: tableName.range))
            }
            
            let tableTy = instantiate(scheme)
            
            guard case let .row(.named(columns)) = tableTy else {
                diagnostics.add(.init(
                    "'\(tableName)' is not a row",
                    at: expr.range
                ))
                return (.error, [:], [:], .some(expr.column.value))
            }

            guard let type = columns[expr.column.value] else {
                diagnostics.add(.init(
                    "Table '\(tableName)' has no column '\(expr.column)'",
                    at: expr.range
                ))
                return (.error, [:], [:], .some(expr.column.value))
            }
            
            return (type, [:], [:], .some(expr.column.value))
        } else {
            guard let scheme = env[expr.column.value] else {
                diagnostics.add(.init(
                    "Column '\(expr.column)' does not exist",
                    at: expr.range
                ))
                return (.error, [:], [:], .some(expr.column.value))
            }
            
            // TODO: Maybe put this in the scheme instantiation?
            if scheme.isAmbiguous {
                diagnostics.add(.ambiguous(expr.column.value, at: expr.column.range))
            }
            
            let type = instantiate(scheme)
            
            return (type, [:], [:], .some(expr.column.value))
        }
    }
    
    mutating func visit(_ expr: borrowing PrefixExpr) -> (Ty, Substitution, Constraints, Names) {
        let (t, s, c, n) = expr.rhs.accept(visitor: &self)
        
        guard let scheme = env[prefix: expr.operator.operator] else {
            diagnostics.add(.init("'\(expr.operator.operator)' is not a valid prefix operator", at: expr.operator.range))
            return (.error, s, c, n)
        }
        
        let tv: Ty = .var(freshTyVar())
        let fnType = instantiate(scheme)
        let sub = unify(fnType, with: .fn(params: [t], ret: tv), at: expr.range)
        return (tv.apply(sub), sub.merging(s), c, n)
    }
    
    mutating func visit(_ expr: borrowing InfixExpr) -> (Ty, Substitution, Constraints, Names) {
        let (lTy, lSub, lCon, lNames) = expr.lhs.accept(visitor: &self)
        let (rTy, rSub, rCon, rNames) = expr.rhs.accept(visitor: &self)
        let names = lNames.merging(rNames)
        
        guard let scheme = env[infix: expr.operator.operator] else {
            diagnostics.add(.init("'\(expr.operator.operator)' is not a valid infix operator", at: expr.operator.range))
            return (.error, rSub.merging(lSub), lCon.merging(rCon), names)
        }
        
        let tv: Ty = .var(freshTyVar())
        let fnType = instantiate(scheme)
        let sub = unify(fnType, with: .fn(params: [lTy.apply(rSub), rTy], ret: tv), at: expr.range)
        return (tv.apply(sub), sub.merging(rSub, lSub), lCon.merging(rCon), names)
    }
    
    mutating func visit(_ expr: borrowing PostfixExpr) -> (Ty, Substitution, Constraints, Names) {
        let (t, s, c, n) = expr.lhs.accept(visitor: &self)
        
        guard let scheme = env[postfix: expr.operator.operator] else {
            diagnostics.add(.init("'\(expr.operator.operator)' is not a valid postfix operator", at: expr.operator.range))
            return (.error, s, c, n)
        }
        
        let tv: Ty = .var(freshTyVar())
        let fnType = instantiate(scheme)
        let sub = unify(fnType, with: .fn(params: [t], ret: tv), at: expr.range)
        return (tv.apply(sub), sub.merging(s), c, n)
    }
    
    mutating func visit(_ expr: borrowing BetweenExpr) -> (Ty, Substitution, Constraints, Names) {
        let (tys, sub, con, names) = visit(many: [expr.value, expr.lower, expr.upper])
        let betSub = unify(instantiate(Builtins.between), with: .fn(params: tys, ret: .bool), at: expr.range)
        return (.bool, betSub.merging(sub), con, names)
    }
    
    mutating func visit(_ expr: borrowing FunctionExpr) -> (Ty, Substitution, Constraints, Names) {
        let (argTys, argSub, argConstraints, argNames) = visit(many: expr.args)
        
        guard let scheme = env[function: expr.name.value, argCount: argTys.count] else {
            diagnostics.add(.init("No such function '\(expr.name)' exits", at: expr.range))
            return (.error, argSub, argConstraints, argNames)
        }
        
        let tv: Ty = .var(freshTyVar())
        let sub = unify(instantiate(scheme), with: .fn(params: argTys, ret: tv), at: expr.range)
        return (tv, sub.merging(argSub), argConstraints, argNames)
    }
    
    mutating func visit(_ expr: borrowing CastExpr) -> (Ty, Substitution, Constraints, Names) {
        let (_, s, c, n) = expr.expr.accept(visitor: &self)
        
        if expr.ty.resolved == nil {
            diagnostics.add(.init("Type '\(expr.ty)' is not a valid type", at: expr.range))
        }
        
        return (.nominal(expr.ty.name.value), s, c, n)
    }
    
    mutating func visit(_ expr: borrowing Expression) -> (Ty, Substitution, Constraints, Names) {
        fatalError("TODO: Clean this up. Should never get called. It's `accept` calls the wrapped method, not this")
    }
    
    mutating func visit(_ expr: borrowing CaseWhenThenExpr) -> (Ty, Substitution, Constraints, Names) {
        let ret: Ty = .var(freshTyVar())
        let (whenTys, whenSub, whenCons, whenNames) = visit(many: expr.whenThen.map(\.when))
        let (thenTys, thenSub, thenCons, thenNames) = visit(many: expr.whenThen.map(\.then))
        
        var sub = whenSub.merging(thenSub)
        var cons = whenCons.merging(thenCons)
        var names = whenNames.merging(thenNames)
        
        if let (t, s, c, n) = expr.case?.accept(visitor: &self) {
            // Each when should have same type as case
            sub = sub.merging(unify(all: [t] + whenTys, at: expr.range), s)
            cons = cons.merging(c)
            names = names.merging(n)
        } else {
            // No case expr, so each when should be a bool
            sub = sub.merging(unify(all: [.bool] + whenTys, at: expr.range))
        }
        
        if let (t, s, c, n) = expr.else?.accept(visitor: &self) {
            sub = sub.merging(unify(all: [t, ret] + thenTys, at: expr.range), s)
            cons = cons.merging(c)
            names = names.merging(n)
        } else {
            sub = sub.merging(unify(all: [ret] + thenTys, at: expr.range))
        }
        
        return (ret, sub, cons, names)
    }
    
    mutating func visit(_ expr: borrowing GroupedExpr) -> (Ty, Substitution, Constraints, Names) {
        let (t, s, c, n) = visit(many: expr.exprs)
        return (.row(.unnamed(t)), s, c, n)
    }
    
    mutating func visit(_ expr: borrowing SelectExpr) -> (Ty, Substitution, Constraints, Names) {
        fatalError()
    }
    
    private mutating func visit(many exprs: [Expression]) -> ([Ty], Substitution, Constraints, Names) {
        var tys: [Ty] = []
        var sub: Substitution = [:]
        var constraints: [TypeVariable: TypeConstraints] = [:]
        var names: Names = .none
        
        for expr in exprs {
            let (t, s, c, n) = expr.accept(visitor: &self)
            tys.append(t.apply(sub))
            sub.merge(s, uniquingKeysWith: {$1})
            constraints.merge(c, uniquingKeysWith: { $0.union($1) })
            names = names.merging(n)
        }
        
        return (tys, sub, constraints, names)
    }
}
