//
//  Type.swift
//  Feather
//
//  Created by Wes Wickwire on 12/17/24.
//

import OrderedCollections

/// A type, these are not just the types define in the tables
/// but rather any value or function that can exist within
/// an expression/statement.
public enum Type: Equatable, CustomStringConvertible, Sendable {
    /// A named type, these are the values defined in the columns.
    case nominal(Substring)
    /// A placeholder for a type that needs to be solved for
    case `var`(TypeVariable)
    /// A function
    indirect case fn(params: [Type], ret: Type)
    /// A row is a value from a `SELECT` statement or a group `(?, ?, ?)`
    case row(Row)
    /// A type that might be null.
    indirect case optional(Type)
    /// A type that has been aliased. These are not in SQL by default
    /// but are from the layer on top that we are adding so a user
    /// can replace a `INTEGER` with a `Bool`
    indirect case alias(Type, Substring)
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
    
    /// Rows or "Tables" can come in the form of two ways.
    /// Named and unnamed. Named is obviously a table from
    /// a FROM or JOIN. Unnamed would be from a subquery or
    /// a row expression `(?, ?, ?)`.
    public enum Row: Equatable, Sendable, ExpressibleByArrayLiteral {
        /// A row that has names for each value
        case named(OrderedDictionary<Substring, Type>)
        /// A row that does not have names. These can come from
        /// using `VALUES (1, 2, 3)`.
        case unnamed([Type])
        /// This is a special row that we don't know the inner types of.
        /// It assumes that all types in it are the same type and of an
        /// unbounded length. Allows us to define functions like `IN` that
        /// take a row as an input but we are unsure of what the inner values are.
        indirect case unknown(Type)
        
        public static let empty: Row = .unnamed([])
        
        public init(arrayLiteral elements: Type...) {
            self = .unnamed(elements)
        }
        
        var first: Type? {
            return switch self {
            case let .named(v): v.values.first
            case let .unnamed(v): v.first
            case let .unknown(t): t
            }
        }
        
        var count: Int {
            return switch self {
            case let .named(v): v.count
            case let .unnamed(v): v.count
            case .unknown: 1
            }
        }
        
        var types: [Type] {
            return switch self {
            case let .named(v): Array(v.values)
            case let .unnamed(v): v
            case let .unknown(t): [t]
            }
        }
        
        func apply(_ s: Substitution) -> Row {
            return switch self {
            case let .named(v): .named(v.mapValues { $0.apply(s) })
            case let .unnamed(v): .unnamed(v.map { $0.apply(s) })
            case let .unknown(t): .unknown(t.apply(s))
            }
        }
        
        func mapTypes(_ transform: (Type) -> Type) -> Row {
            switch self {
            case let .named(values):
                return .named(values.mapValues(transform))
            case let .unnamed(values):
                return .unnamed(values.map(transform))
            case let .unknown(value):
                return .unknown(transform(value))
            }
        }
    }
    
    static let text: Type = .nominal("TEXT")
    static let int: Type = .nominal("INT")
    static let integer: Type = .nominal("INTEGER")
    static let real: Type = .nominal("REAL")
    static let blob: Type = .nominal("BLOB")
    static let any: Type = .nominal("ANY")
    static let bool: Type = .nominal("BOOL")
    
    public var description: String {
        return switch self {
        case let .nominal(typeName): typeName.description
        case let .var(typeVariable): typeVariable.description
        case let .fn(args, ret): "(\(args.map(\.description).joined(separator: ","))) -> \(ret)"
        case let .row(row): switch row {
            case let .named(values): "(\(values.map { "\($0):\($1)" }.joined(separator: ",")))"
            case let .unnamed(values): "(\(values.map(\.description).joined(separator: ",")))"
            case let .unknown(ty): "(\(ty)...)"
            }
        case let .optional(ty): "\(ty)?"
        case let .alias(t, a): "(\(t) AS \(a))"
        case .error: "<<error>>"
        }
    }
    
    func apply(_ s : Substitution) -> Type {
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
                params: params.map { $0.apply(s) },
                ret: ret.apply(s)
            )
        case let .row(tys):
            return .row(tys.apply(s))
        case let .optional(ty):
            return .optional(ty)
        case let .alias(t, a):
            return .alias(t.apply(s), a)
        case .nominal, .error:
            // Literals can't be substituted for.
            return self
        }
    }
    
    func unify(
        with other: Type,
        at range: Range<String.Index>,
        diagnostics: inout Diagnostics
    ) -> Substitution {
        // If they are the same, no need to unify
        guard self != other else { return [:] }
        
        switch (self, other) {
        case (.error, _), (_, .error):
            // Already had an upstream error so no need to emit any more diagnostics
            return [:]
        case let (.var(tv1), .var(tv2)):
            // Unify to type variables.
            // We need to prioritize what gets substituded for what
            // by its kind.
            // So if we get an `integer` and `float`, we want to promote
            // the `integer` to a `float`, so we sub the int for the float
            switch (tv1.kind, tv2.kind) {
            case (.general, _):
                // General can always be substitued out
                return [tv1: other]
            case (_, .general):
                // General can always be substitued out
                return [tv2: self]
            case (.float, .integer):
                // self: float, other: int
                // substitute other for self
                return [tv2: self]
            case (.integer, .float):
                // self: int, other: float
                // substitute self for other
                return [tv1: other]
            default:
                return [tv1: other]
            }
        case let (.var(tv), ty):
            return [tv: ty]
        case let (ty, .var(tv)):
            return [tv: ty]
        case (.integer, .real):
            return [:]
        case (.real, .integer):
            return [:]
        case (.nominal, .nominal):
            guard self != other else { return [:] }
            diagnostics.add(.unableToUnify(self, with: other, at: range))
            return [:]
        case let (.optional(t1), t2):
            return t1.unify(with: t2, at: range, diagnostics: &diagnostics)
        case let (t1, .optional(t2)):
            return t1.unify(with: t2, at: range, diagnostics: &diagnostics)
        case let (.fn(args1, ret1), .fn(args2, ret2)):
            let args = unify(args1, with: args2, at: range, diagnostics: &diagnostics)
            let ret = ret1.apply(args).unify(with: ret2.apply(args), at: range, diagnostics: &diagnostics)
            return ret.merging(args)
        case let (.row(.unknown(ty)), .row(rhs)):
            return unify(all: rhs.types, with: ty, at: range, diagnostics: &diagnostics)
        case let (.row(lhs), .row(.unknown(ty))):
            return unify(all: lhs.types, with: ty, at: range, diagnostics: &diagnostics)
        case let (.row(rhs), .row(lhs)) where lhs.count == rhs.count:
            return unify(rhs.types, with: lhs.types, at: range, diagnostics: &diagnostics)
        case let (.row(row), t):
            if row.count == 1, let first = row.first {
                return first.unify(with: t, at: range, diagnostics: &diagnostics)
            } else {
                diagnostics.add(.unableToUnify(self, with: other, at: range))
                return [:]
            }
        case let (t, .row(row)):
            if row.count == 1, let first = row.first {
                return first.unify(with: t, at: range, diagnostics: &diagnostics)
            } else {
                diagnostics.add(.unableToUnify(self, with: other, at: range))
                return [:]
            }
        case let (.alias(t1, _), t2):
            return t1.unify(with: t2, at: range, diagnostics: &diagnostics)
        case let (t1, .alias(t2, _)):
            return t2.unify(with: t1, at: range, diagnostics: &diagnostics)
        default:
            diagnostics.add(.unableToUnify(self, with: other, at: range))
            return [:]
        }
    }
    
    private func unify<T1: Collection, T2: Collection>(
        _ tys: T1,
        with others: T2,
        at range: Range<String.Index>,
        diagnostics: inout Diagnostics
    ) -> Substitution
        where T1.Element == Type, T2.Element == Type
    {
        assert(tys.count == others.count)
        
        var sub: Substitution = [:]
        var tys = tys.makeIterator()
        var others = others.makeIterator()
        
        while let ty1 = tys.next(), let ty2 = others.next() {
            sub.merge(ty1.apply(sub).unify(with: ty2.apply(sub), at: range, diagnostics: &diagnostics))
        }
        
        return sub
    }
    
    private func unify<T1: Collection>(
        all tys: T1,
        with ty1: Type,
        at range: Range<String.Index>,
        diagnostics: inout Diagnostics
    ) -> Substitution
        where T1.Element == Type
    {
        var sub: Substitution = [:]
        
        for ty2 in tys {
            sub.merge(
                ty1.apply(sub).unify(with: ty2.apply(sub), at: range, diagnostics: &diagnostics),
                uniquingKeysWith: { $1 }
            )
        }
        
        return sub
    }
    
    private func validateCanUnify(
        with tvKind: TypeVariable.Kind,
        diagnostics: inout Diagnostics,
        at range: Range<Substring.Index>
    ) {
        switch tvKind {
        case .general:
            return
        case .integer:
            switch self {
            case .int, .integer, .real: return
            default: diagnostics.add(.unableToUnify(self, with: .integer, at: range))
            }
        case .float:
            switch self {
            case .int, .integer, .real: return
            default: diagnostics.add(.unableToUnify(self, with: .real, at: range))
            }
        }
    }
}

/// A type variable is a type placeholder for an expression who's type we need to solve.
public struct TypeVariable: Hashable, CustomStringConvertible, ExpressibleByIntegerLiteral, Sendable {
    /// The unique integer associated with the variable.
    /// These are just incremented as they are created.
    let n: Int
    /// What kind or group this type variable belongs too.
    let kind: Kind
    
    /// There are different type of type variables.
    /// Each are spawned from different usages.
    enum Kind {
        /// `integer` is any type variable from an integer literal e.g. `0`
        case integer
        /// `float` is any type variable from an float literal e.g. `0.0`
        case float
        /// `general` is any type variable that does not fall into the above
        case general
    }
    
    init(_ n: Int, kind: Kind) {
        self.n = n
        self.kind = kind
    }
    
    public init(integerLiteral value: Int) {
        self.n = value
        self.kind = .general
    }
    
    /// The type to use for an expression if no concrete type was
    /// found in the solution.
    ///
    /// e.g. `1 + 1`, each literal is not bound to a concrete type
    /// like a column. So each would still be a variable after the
    /// substitution is applied. In which a default is needed.
    var defaultType: Type {
        return switch kind {
        case .general: .any
        case .integer: .integer
        case .float: .real
        }
    }
    
    public var description: String {
        return "τ\(n)"
    }
}
