//
//  TableOptionsSyntax.swift
//  PureSQL
//
//  Created by Wes Wickwire on 5/7/25.
//

struct TableOptionsSyntax: Syntax, Sendable, CustomStringConvertible {
    let id: SyntaxId
    let kind: Kind
    let location: SourceLocation

    struct Kind: OptionSet {
        let rawValue: UInt8

        init(rawValue: UInt8) {
            self.rawValue = rawValue
        }

        static let withoutRowId = Kind(rawValue: 1 << 0)
        static let strict = Kind(rawValue: 1 << 1)
    }

    var description: String {
        guard kind.rawValue > 0 else { return "[]" }
        var opts: [String] = []
        if kind.contains(.withoutRowId) { opts.append("WITHOUT ROWID") }
        if kind.contains(.strict) { opts.append("STRICT") }
        return "[\(opts.joined(separator: ", "))]"
    }
}
