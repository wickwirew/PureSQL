//
//  Environment.swift
//
//
//  Created by Wes Wickwire on 11/4/24.
//

import OrderedCollections

/// The environment for which every query and statement is
/// type checked against as well as any other static analysis.
struct Environment {
    private var identifiers: OrderedDictionary<Substring, TypeContainer> = [:]
    
    /// Holds the type in the map.
    struct TypeContainer {
        let type: Type
        /// We need to track ambiguous items. We could store
        /// each as an array but that seems like a bad idea due to
        /// the number of allocations that would add.
        ///
        /// This just allows us to store the flag right with the type.
        ///
        /// Is flipped to `true` when the same name is inserted into
        /// the environment twice or more.
        let isAmbiguous: Bool
        /// A value inserted into the environment that should only be
        /// available by direct access via name.
        /// The value will not be included when iterating over every
        /// value in the environment.
        ///
        /// Useful for FTS tables. The `rank` column is available
        /// during a query. However if they do a `SELECT *` it should
        /// not be included into the result columns
        let explicitAccessOnly: Bool
        /// Whether or not this value is inherited from a parent environment.
        /// In a subquery we inherit the values from the parent environment
        /// but with the caveat that they are overridable and won't be consider
        /// ambiguous if something was inserted with the same name.
        let isFromParent: Bool
    }
    
    init() {}
    
    private init(identifiers: OrderedDictionary<Substring, TypeContainer>) {
        self.identifiers = identifiers
    }

    /// Inserts or updates the type for the given name
    mutating func upsert(_ name: Substring, ty: Type, explicitAccessOnly: Bool = false) {
        identifiers[name] = TypeContainer(
            type: ty,
            isAmbiguous: false,
            explicitAccessOnly: explicitAccessOnly,
            isFromParent: false
        )
    }
    
    /// Inserts the type for the given name. If the name
    /// already exists it will be marked as ambiguous
    mutating func insert(_ name: Substring, ty: Type, explicitAccessOnly: Bool = false) {
        // If it already exists, mark it as ambiguous except for the case
        // where its from a parent environment.
        if let existing = identifiers[name], !existing.isFromParent {
            identifiers[name] = TypeContainer(
                type: existing.type,
                isAmbiguous: true,
                explicitAccessOnly: explicitAccessOnly,
                isFromParent: false
            )
        } else {
            identifiers[name] = TypeContainer(
                type: ty,
                isAmbiguous: false,
                explicitAccessOnly: explicitAccessOnly,
                isFromParent: false
            )
        }
    }
    
    /// Returns a copy of `self` but with all identifiers in the environment
    /// as overridable since they are from a parent environment.
    func asParent() -> Environment {
        return Environment(identifiers: identifiers.mapValues { container in
            TypeContainer(
                type: container.type,
                isAmbiguous: container.isAmbiguous,
                explicitAccessOnly: container.explicitAccessOnly,
                isFromParent: true
            )
        })
    }
    
    mutating func rename(_ key: Substring, to newValue: Substring) {
        guard let value = identifiers[key] else { return }
        identifiers[key] = nil
        identifiers[newValue] = value
    }
    
    subscript(_ key: Substring) -> TypeContainer? {
        return identifiers[key]
    }
    
    subscript(function name: Substring, argCount argCount: Int) -> TypeScheme? {
        // TODO: Move this out of the env
        guard let scheme = Builtins.functions[name],
              case let .fn(params, ret) = scheme.type else { return nil }
        
        // This is how variadics are handled. If a variadic function is called
        // we extend the signature to match the input count. It is always
        // assumed the last parameter is the variadic.
        let numberOfArgsToAdd = argCount - params.count
        
        guard scheme.variadic, argCount > 0, let last = params.last else { return scheme }
        
        return TypeScheme(
            typeVariables: scheme.typeVariables,
            type: .fn(
                params: params + (0..<numberOfArgsToAdd).map { _ in last },
                ret: ret
            ),
            variadic: true
        )
    }
    
    subscript(prefix op: Operator) -> TypeScheme? {
        return switch op {
        case .plus: Builtins.pos
        case .minus: Builtins.negate
        case .tilde: Builtins.bitwiseNot
        default: nil
        }
    }
    
    subscript(infix op: Operator) -> TypeScheme? {
        return switch op {
        case .plus, .minus, .multiply, .divide, .bitwuseOr,
             .bitwiseAnd, .shl, .shr, .mod:
            Builtins.arithmetic
        case .eq, .eq2, .neq, .neq2, .lt, .gt, .lte, .gte, .is,
             .notNull, .notnull, .like, .isNot, .isDistinctFrom,
             .isNotDistinctFrom, .between, .and, .or, .isnull, .not:
            Builtins.comparison
        case .in: Builtins.in
        case .concat: Builtins.concatOp
        case .doubleArrow: Builtins.extract
        case .match: Builtins.match
        case .regexp: Builtins.regexp
        case .arrow: Builtins.extractJson
        case .glob: Builtins.glob
        default: nil
        }
    }
    
    subscript(postfix op: Operator) -> TypeScheme? {
        return switch op {
        case .collate: Builtins.concatOp
        case .escape: Builtins.escape
        default: nil
        }
    }
}

extension Environment: CustomStringConvertible {
    var description: String {
        return self.identifiers.map { "\($0.key): \($0.value)" }.joined(separator: "\n")
    }
}

extension Environment: Sequence {
    func makeIterator() -> Iterator {
        return Iterator(inner: identifiers.makeIterator())
    }
    
    struct Iterator: IteratorProtocol {
        var inner: OrderedDictionary<Substring, Environment.TypeContainer>.Iterator
        
        mutating func next() -> (Substring, Type)? {
            guard let value = inner.next() else { return nil }
            guard !value.value.explicitAccessOnly else { return next() }
            return (value.key, value.value.type)
        }
    }
}
