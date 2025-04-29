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
    
    /// The underlying root inner type
    var root: Type {
        return switch self {
        case .alias(let t, _): t.root
        case .optional(let t): t.root
        default: self
        }
    }
    
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
    
    var isRow: Bool {
        switch self {
        case .row: true
        default: false
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
            return .optional(ty.apply(s))
        case let .alias(t, a):
            return .alias(t.apply(s), a)
        case .nominal, .error:
            // Literals can't be substituted for.
            return self
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
    enum Kind: Int, Equatable, Comparable {
        /// `general` is any type variable that does not fall into the above
        case general = 0
        /// `integer` is any type variable from an integer literal e.g. `0`
        case integer = 1
        /// `float` is any type variable from an float literal e.g. `0.0`
        case float = 2
        
        static func <(lhs: Kind, rhs: Kind) -> Bool {
            return lhs.rawValue < rhs.rawValue
        }
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
    
    func with(kind: Kind) -> TypeVariable {
        return TypeVariable(n, kind: kind)
    }
}
