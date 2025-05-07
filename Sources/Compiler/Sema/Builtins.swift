//
//  Builtins.swift
//  Feather
//
//  Created by Wes Wickwire on 3/3/25.
//

import OrderedCollections

enum Builtins {
    /// Operators
    static let negate = TypeScheme(typeVariables: [0], type: .fn(params: [.var(0)], ret: .var(0)))
    static let bitwiseNot = TypeScheme(typeVariables: [0], type: .fn(params: [.var(0)], ret: .var(0)))
    static let pos = TypeScheme(typeVariables: [0], type: .fn(params: [.var(0)], ret: .var(0)))
    static let between = TypeScheme(typeVariables: [0], type: .fn(params: [.var(0), .var(0), .var(0)], ret: .bool))
    static let arithmetic = TypeScheme(typeVariables: [0], type: .fn(params: [.var(0), .var(0)], ret: .var(0)))
    static let comparison = TypeScheme(typeVariables: [0], type: .fn(params: [.var(0), .var(0)], ret: .bool))
    static let `in` = TypeScheme(typeVariables: [0], type: .fn(params: [.var(0), .row(.unknown(.var(0)))], ret: .bool))
    static let concatOp = TypeScheme(typeVariables: [0, 1], type: .fn(params: [.var(0), .var(1)], ret: .text))
    static let extract = TypeScheme(typeVariables: [0, 1], type: .fn(params: [.var(0)], ret: .var(1)))
    static let extractJson = TypeScheme(typeVariables: [0], type: .fn(params: [.var(0)], ret: .any))
    static let collate = TypeScheme(typeVariables: [], type: .fn(params: [.text], ret: .text))
    static let escape = TypeScheme(typeVariables: [], type: .fn(params: [.text], ret: .text))
    static let match = TypeScheme(typeVariables: [0], type: .fn(params: [.var(0), .text], ret: .bool))
    static let regexp = TypeScheme(typeVariables: [], type: .fn(params: [.text, .text], ret: .bool))
    static let glob = TypeScheme(typeVariables: [], type: .fn(params: [.text, .text], ret: .bool))
    
    static let functions: OrderedDictionary<Substring, TypeScheme> = [
        // Scalar functions
        "abs": TypeScheme(typeVariables: [.integer(0)], type: .fn(params: [.var(.integer(0))], ret: .var(.integer(0)))),
        "changes": TypeScheme(typeVariables: [], type: .fn(params: [], ret: .integer)),
        "char": TypeScheme(typeVariables: [], type: .fn(params: [.integer], ret: .text), variadic: true),
        "coalesce": TypeScheme(typeVariables: [0], type: .fn(params: [.optional(.var(0))], ret: .var(0)), variadic: true),
        "concat": TypeScheme(typeVariables: [0], type: .fn(params: [.var(0)], ret: .text)),
        "concat_ws": TypeScheme(typeVariables: [0], type: .fn(params: [.text, .var(0)], ret: .text)),
        "format": TypeScheme(typeVariables: [0], type: .fn(params: [.text, .var(0)], ret: .text)),
        "glob": Builtins.glob,
        "hex": TypeScheme(typeVariables: [], type: .fn(params: [.blob], ret: .text)),
        // iif - Cannot support currently since it takes its parameters in 2's
        "ifnull": TypeScheme(typeVariables: [0], type: .fn(params: [.var(0), .var(1)], ret: .var(1))),
        "instr": TypeScheme(typeVariables: [], type: .fn(params: [.text, .text], ret: .integer)),
        "last_insert_rowid": TypeScheme(typeVariables: [], type: .fn(params: [], ret: .integer)),
        "length": TypeScheme(typeVariables: [], type: .fn(params: [.text], ret: .integer)),
        "like": TypeScheme(typeVariables: [], type: .fn(params: [.text, .text], ret: .bool)),
        "likelihood": TypeScheme(typeVariables: [0], type: .fn(params: [.var(0), .real], ret: .var(0))),
        "likely": TypeScheme(typeVariables: [0], type: .fn(params: [.var(0)], ret: .var(0))),
        "lower": TypeScheme(typeVariables: [], type: .fn(params: [.text], ret: .text)),
        "ltrim": TypeScheme(typeVariables: [], type: .fn(params: [.text, .text], ret: .text)),
        "max": TypeScheme(typeVariables: [0], type: .fn(params: [.var(0)], ret: .var(0)), variadic: true),
        "min": TypeScheme(typeVariables: [0], type: .fn(params: [.var(0)], ret: .var(0)), variadic: true),
        "nullif": TypeScheme(typeVariables: [0], type: .fn(params: [.var(0), .var(0)], ret: .optional(.var(0)))),
        "octet_length": TypeScheme(typeVariables: [], type: .fn(params: [.text], ret: .integer)),
        "random": TypeScheme(typeVariables: [], type: .fn(params: [], ret: .integer)),
        "randomblob": TypeScheme(typeVariables: [], type: .fn(params: [.integer], ret: .blob)),
        "replace": TypeScheme(typeVariables: [], type: .fn(params: [.text, .text, .text], ret: .text)),
        "round": TypeScheme(typeVariables: [], type: .fn(params: [.real, .integer], ret: .real)),
        "rtrim": TypeScheme(typeVariables: [], type: .fn(params: [.text, .text], ret: .text)),
        "sign": TypeScheme(typeVariables: [.integer(0)], type: .fn(params: [.var(.integer(0))], ret: .integer)),
        "soundex": TypeScheme(typeVariables: [], type: .fn(params: [.text], ret: .text)),
        "substr": TypeScheme(typeVariables: [], type: .fn(params: [.text, .integer, .integer], ret: .text)),
        "substring": TypeScheme(typeVariables: [], type: .fn(params: [.text, .integer, .integer], ret: .text)),
        "trim": TypeScheme(typeVariables: [], type: .fn(params: [.text, .text], ret: .text)),
        "typeof": TypeScheme(typeVariables: [0], type: .fn(params: [.var(0)], ret: .text)),
        "unhex": TypeScheme(typeVariables: [], type: .fn(params: [.text], ret: .blob)),
        "unicode": TypeScheme(typeVariables: [], type: .fn(params: [.text], ret: .integer)),
        "unlikely": TypeScheme(typeVariables: [0], type: .fn(params: [.var(0)], ret: .var(0))),
        "upper": TypeScheme(typeVariables: [], type: .fn(params: [.text], ret: .text)),
        "zeroblob": TypeScheme(typeVariables: [], type: .fn(params: [.integer], ret: .blob)),

        // Aggregate Functions
        "avg": TypeScheme(typeVariables: [.integer(0)], type: .fn(params: [.var(.integer(0))], ret: .var(.integer(0)))),
        "count": TypeScheme(typeVariables: [0], type: .fn(params: [.var(0)], ret: .integer)),
        "group_concat": TypeScheme(typeVariables: [], type: .fn(params: [.text, .text], ret: .text)),
        "string_agg": TypeScheme(typeVariables: [], type: .fn(params: [.text, .text], ret: .text)),
        // 'max' and 'min' are added through the scalar functions and can be reused.
        // In the future we may need to separate these if we store them separately
        "sum": TypeScheme(typeVariables: [.integer(0)], type: .fn(params: [.var(.integer(0))], ret: .var(.integer(0)))),
        "total": TypeScheme(typeVariables: [.integer(0)], type: .fn(params: [.var(.integer(0))], ret: .var(.integer(0)))),
    ]
}
