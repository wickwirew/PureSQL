//
//  ParsingError.swift
//  
//
//  Created by Wes Wickwire on 10/8/24.
//

struct ParsingError: Error, CustomStringConvertible {
    let description: String
    let sourceRange: Range<String.Index>
}

extension ParsingError {
    static func unexpectedToken(of kind: Token.Kind, at sourceRange: Range<String.Index>) -> ParsingError {
        ParsingError(description: "Unexpected token \(kind)", sourceRange: sourceRange)
    }
    
    static func expectedSymbol(at sourceRange: Range<String.Index>) -> ParsingError {
        ParsingError(description: "Expected symbol", sourceRange: sourceRange)
    }
    
    static func expectedNumeric(at sourceRange: Range<String.Index>) -> ParsingError {
        ParsingError(description: "Expected numeric", sourceRange: sourceRange)
    }
    
    static func unknown(type: Substring, at sourceRange: Range<String.Index>) -> ParsingError {
        ParsingError(description: "Unknown type \(type)", sourceRange: sourceRange)
    }
    
    static func expected(_ tokenKinds: Token.Kind..., at sourceRange: Range<String.Index>) -> ParsingError {
        expected(tokenKinds, at: sourceRange)
    }
    
    static func expected(_ tokenKinds: [Token.Kind], at sourceRange: Range<String.Index>) -> ParsingError {
        ParsingError(
            description: "Expected \(tokenKinds.map(\.description).joined(separator: " or "))",
            sourceRange: sourceRange
        )
    }
}
