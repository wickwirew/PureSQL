//
//  Builtins.swift
//  Feather
//
//  Created by Wes Wickwire on 3/3/25.
//

import OrderedCollections

enum Builtins {
    /// Operators
    static let negate = Function(.var(0), returning: .var(0))
    static let bitwiseNot = Function(.var(0), returning: .var(0))
    static let pos = Function(.var(0), returning: .var(0))
    static let between = Function(.var(0), .var(0), .var(0), returning: .integer)
    static let arithmetic = Function(.var(0), .var(0), returning: .var(0))
    static let divide = Function(.var(0), .var(0), returning: .var(0)) { _, _, _ in
        fatalError("check for integer division")
    }
    static let comparison = Function(.var(0), .var(0), returning: .integer)
    static let `in` = Function(.var(0), .row(.unknown(.var(0))), returning: .integer)
    static let concatOp = Function(.var(0), .var(1), returning: .text)
    static let extract = Function(.var(0), returning: .var(1))
    static let extractJson = Function(.var(0), returning: .any)
    static let collate = Function(.text, returning: .text)
    static let escape = Function(.text, returning: .text)
    static let match = Function(.var(0), .text, returning: .integer)
    static let regexp = Function(.text, .text, returning: .integer)
    static let glob = Function(.text, .text, returning: .integer)
    
    static let functions: OrderedDictionary<Substring, Function> = {
        // TODO: Clean this up. SQLite isnt casing dependant but we are at the moment.
        // TODO: So insert each function twice, under the lower and upper cased name.
        
        var functions = baseFunctions
        
        for (name, fn) in baseFunctions {
            functions[name.uppercased()[...]] = fn
        }
        
        return functions
    }()

    private static let baseFunctions: OrderedDictionary<Substring, Function> = [
        // Scalar functions
        "abs": Function(.var(.integer(0)), returning: .var(.integer(0))),
        "changes": Function(returning: .integer),
        "char": Function(.integer, returning: .text, variadic: true),
        "coalesce": Function(.optional(.var(0)), returning: .var(0), variadic: true),
        "concat": Function(.var(0), returning: .text),
        "concat_ws": Function(.text, .var(0), returning: .text),
        "format": Function(.text, .var(0), returning: .text),
        "glob": Builtins.glob,
        "hex": Function(.blob, returning: .text),
        // iif - Cannot support currently since it takes its parameters in 2's
        "ifnull": Function(.var(0), .var(1), returning: .var(1)),
        "instr": Function(.text, .text, returning: .integer),
        "last_insert_rowid": Function(returning: .integer),
        "length": Function(.text, returning: .integer),
        "like": Function(.text, .text, returning: .integer),
        "likelihood": Function(.var(0), .real, returning: .var(0)),
        "likely": Function(.var(0), returning: .var(0)),
        "lower": Function(.text, returning: .text),
        "ltrim": Function(.text, .text, returning: .text),
        "max": Function(.var(0), returning: .var(0), variadic: true),
        "min": Function(.var(0), returning: .var(0), variadic: true),
        "nullif": Function(.var(0), .var(0), returning: .optional(.var(0))),
        "octet_length": Function(.text, returning: .integer),
        "random": Function(returning: .integer),
        "randomblob": Function(.integer, returning: .blob),
        "replace": Function(.text, .text, .text, returning: .text),
        "round": Function(.real, .integer, returning: .real),
        "rtrim": Function(.text, .text, returning: .text),
        "sign": Function(.var(.integer(0)), returning: .integer),
        "soundex": Function(.text, returning: .text),
        "substr": Function(.text, .integer, .integer, returning: .text),
        "substring": Function(.text, .integer, .integer, returning: .text),
        "trim": Function(.text, .text, returning: .text),
        "typeof": Function(.var(0), returning: .text),
        "unhex": Function(.text, returning: .blob),
        "unicode": Function(.text, returning: .integer),
        "unlikely": Function(.var(0), returning: .var(0)),
        "upper": Function(.text, returning: .text),
        "zeroblob": Function(.integer, returning: .blob),
        "bm25": Function(.var(0), returning: .real),

        // Datetime
        "unixepoch": Function(returning: .integer),
        "julianday": Function(returning: .real),
        "strftime": strftime,
        "date": Function(.text, returning: .text, variadic: true),
        "time": Function(.text, returning: .text, variadic: true),
        "datetime": Function(.text, returning: .text, variadic: true),
        "timediff": Function(.text, returning: .text),

        // Aggregate Functions
        "avg": Function(.var(.integer(0)), returning: .var(.integer(0))),
        "count": Function(.var(0), returning: .integer),
        "group_concat": groupConcat,
        "string_agg": Function(.text, .text, returning: .text),
        // 'max' and 'min' are added through the scalar functions and can be reused.
        // In the future we may need to separate these if we store them separately
        "sum": Function(.var(.integer(0)), returning: .var(.integer(0))),
        "total": Function(.var(.integer(0)), returning: .var(.integer(0))),
    ]
    
    static let groupConcat = Function(
        .text,
        returning: .text,
        overloads: [Function.Overload(.text, returning: .text)]
    )
    
    static let strftime = Function(
        .text,
        returning: .text,
        variadic: true
    ) { args, location, diagnostics in
        guard args.count == 2,
              case let .string(first) = args[0].literal?.kind,
              case let .string(second) = args[1].literal?.kind,
              first == "%s",
              second == "now" else { return }
        
        diagnostics.add(.init(
            "Function returns the seconds as TEXT, not an INTEGER. Use unixepoch() instead",
            level: .warning,
            at: location
        ))
    }
}
