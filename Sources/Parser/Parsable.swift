//
//  Parsable.swift
//
//
//  Created by Wes Wickwire on 10/12/24.
//

protocol Parsable {
    associatedtype P: Parser
    static var parser: P { get }
}

extension Parsable where P.Output == Self {
    init(sql: String) throws {
        var state = try ParserState(Lexer(source: sql))
        self = try Self.parser.parse(state: &state)
    }
    
    static func parse(state: inout ParserState) throws -> P.Output {
        try Self.parser.parse(state: &state)
    }
    
    static func parse(detached state: ParserState) throws -> P.Output {
        var state = state
        return try Self.parser.parse(state: &state)
    }
}
