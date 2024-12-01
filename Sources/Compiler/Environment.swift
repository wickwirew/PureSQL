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
    private var identifiers: OrderedDictionary<Substring, TyContainer> = [:]
    
    private var functions: OrderedDictionary<Substring, TypeScheme> = [
        "MAX": Builtins.max
    ]
    
    struct TyContainer {
        let type: Ty
        let isAmbiguous: Bool
    }
    
    init() {}

    /// Inserts or updates the type for the given name
    mutating func upsert(_ name: Substring, ty: Ty) {
        identifiers[name] = TyContainer(type: ty, isAmbiguous: false)
    }
    
    /// Inserts the type for the given name. If the name
    /// already exists it will be marked as ambiguous
    mutating func insert(_ name: Substring, ty: Ty) {
        if let existing = identifiers[name] {
            identifiers[name] = TyContainer(type: existing.type, isAmbiguous: true)
        } else {
            identifiers[name] = TyContainer(type: ty, isAmbiguous: false)
        }
    }
    
    mutating func rename(_ key: Substring, to newValue: Substring) {
        guard let value = identifiers[key] else { return }
        identifiers[key] = nil
        identifiers[newValue] = value
    }
    
    subscript(_ key: Substring) -> TyContainer? {
        return identifiers[key]
    }
    
    subscript(function name: Substring, argCount argCount: Int) -> TypeScheme? {
        // TODO: Move this out of the env
        guard let scheme = self.functions[name],
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
        case .concat: Builtins.concat
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
        case .collate: Builtins.concat
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
    typealias Iterator = OrderedDictionary<Substring, Environment.TyContainer>.Iterator
    
    func makeIterator() -> OrderedDictionary<Substring, Environment.TyContainer>.Iterator {
        return identifiers.makeIterator()
    }
}

struct Builtins {
    /// Operators
    static let negate = TypeScheme(typeVariables: [0], type: .fn(params: [.var(0)], ret: .var(0)))
    static let bitwiseNot = TypeScheme(typeVariables: [0], type: .fn(params: [.var(0)], ret: .var(0)))
    static let pos = TypeScheme(typeVariables: [0], type: .fn(params: [.var(0)], ret: .var(0)))
    static let between = TypeScheme(typeVariables: [0], type: .fn(params: [.var(0), .var(0), .var(0)], ret: .bool))
    static let arithmetic = TypeScheme(typeVariables: [0], type: .fn(params: [.var(0), .var(0)], ret: .var(0)))
    static let comparison = TypeScheme(typeVariables: [0], type: .fn(params: [.var(0), .var(0)], ret: .bool))
    static let `in` = TypeScheme(typeVariables: [0], type: .fn(params: [.var(0), .row(.unknown(.var(0)))], ret: .bool))
    static let concat = TypeScheme(typeVariables: [0, 1], type: .fn(params: [.var(0), .var(1)], ret: .text))
    static let extract = TypeScheme(typeVariables: [0, 1], type: .fn(params: [.var(0)], ret: .var(1)))
    static let extractJson = TypeScheme(typeVariables: [0], type: .fn(params: [.var(0)], ret: .any))
    static let collate = TypeScheme(typeVariables: [], type: .fn(params: [.text], ret: .text))
    static let escape = TypeScheme(typeVariables: [], type: .fn(params: [.text], ret: .text))
    static let match = TypeScheme(typeVariables: [0], type: .fn(params: [.var(0), .text], ret: .bool))
    static let regexp = TypeScheme(typeVariables: [], type: .fn(params: [.text, .text], ret: .bool))
    static let glob = TypeScheme(typeVariables: [], type: .fn(params: [.text, .text], ret: .bool))
    
    /// Functions
    static let max = TypeScheme(typeVariables: [0], type: .fn(params: [.var(0)], ret: .var(0)), variadic: true)
}

struct TypeScheme: CustomStringConvertible, Sendable {
    let typeVariables: [TypeVariable]
    let type: Ty
    let variadic: Bool
    
    init(
        typeVariables: [TypeVariable],
        type: Ty,
        variadic: Bool = false
    ) {
        self.typeVariables = typeVariables
        self.type = type
        self.variadic = variadic
    }
    
    init(_ type: Ty) {
        self.typeVariables = []
        self.type = type
        self.variadic = false
    }
    
    var description : String {
        return "∀\(typeVariables.map(\.description).joined(separator: ", ")).\(self.type)"
    }
}
