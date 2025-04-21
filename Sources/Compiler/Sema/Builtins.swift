//
//  Builtins.swift
//  Feather
//
//  Created by Wes Wickwire on 3/3/25.
//

enum Builtins {
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
    static let sum = TypeScheme(typeVariables: [TypeVariable(0, kind: .integer)], type: .fn(params: [.var(TypeVariable(0, kind: .integer))], ret: .var(TypeVariable(0, kind: .integer))))
}
