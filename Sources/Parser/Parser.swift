//
//  Parser.swift
//
//
//  Created by Wes Wickwire on 10/9/24.
//

public protocol Parser {
    associatedtype Output
    func parse(state: inout ParserState) throws -> Output
}

public struct ParserState {
    private var lexer: Lexer
    private(set) var current: Token
    private(set) var peek: Token
    
    init(_ lexer: Lexer) throws {
        self.lexer = lexer
        self.current = try self.lexer.next()
        self.peek = try self.lexer.next()
    }
    
    public init(_ source: String) throws {
        try self.init(Lexer(source: source))
    }
}

extension ParserState {
    var range: Range<String.Index> {
        return current.range
    }
    
    /// Gets the next token in the source stream
    mutating func take() throws -> Token {
        let result = current
        try skip()
        return result
    }
    
    /// Gets the next token if it is of the input kind
    mutating func take(if kind: Token.Kind) throws -> Bool {
        guard current.kind == kind else { return false }
        try skip()
        return true
    }
    
    /// Consumes the next token and validates it is of the input kind
    mutating func take(if kind: Token.Kind, or other: Token.Kind) throws -> Bool {
        guard current.kind == kind || current.kind == other else {
            return false
        }
        
        try skip()
        return true
    }
    
    /// Consumes the next token and validates it is of the input kind
    mutating func take(_ kind: Token.Kind) throws {
        guard current.kind == kind else {
            throw ParsingError.unexpectedToken(of: current.kind, at: current.range)
        }
        
        try skip()
    }
    
    mutating func skip() throws {
        current = peek
        peek = try lexer.next()
    }
    
    func `is`(of kind: Token.Kind) -> Bool {
        return current.kind == kind
    }
}
