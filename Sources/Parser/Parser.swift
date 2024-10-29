//
//  Parser.swift
//
//
//  Created by Wes Wickwire on 10/9/24.
//

protocol Parser {
    associatedtype Output
    func parse(state: inout ParserState) throws -> Output
}

extension Parser {
    func parse(_ source: String) throws -> Output {
        var state = try ParserState(Lexer(source: source))
        return try parse(state: &state)
    }
}

struct ParserState {
    private var lexer: Lexer
    private(set) var current: Token
    private(set) var peek: Token
    private(set) var peek2: Token
    private(set) var parameterIndex: Int = 0
    
    init(_ lexer: Lexer) throws {
        self.lexer = lexer
        self.current = try self.lexer.next()
        self.peek = try self.lexer.next()
        self.peek2 = try self.lexer.next()
    }
}

extension ParserState {
    var range: Range<String.Index> {
        return current.range
    }
    
    func range(from range: Range<String.Index>) -> Range<String.Index> {
        return range.lowerBound..<current.range.upperBound
    }
    
    func skippingOne() throws -> ParserState {
        var copy = self
        try copy.skip()
        return copy
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
    mutating func take(if kind: Token.Kind, and other: Token.Kind) throws -> Bool {
        guard current.kind == kind && peek.kind == other else {
            return false
        }
        
        try skip()
        try skip()
        return true
    }
    
    /// Consumes the next token and validates it is of the input kind
    mutating func consume(_ kind: Token.Kind) throws {
        guard current.kind == kind else {
            throw ParsingError.unexpectedToken(of: current.kind, at: current.range)
        }
        
        try skip()
    }
    
    /// Consumes the next token and validates it is of the input kind
    mutating func take(_ kind: Token.Kind) throws -> Token {
        guard current.kind == kind else {
            throw ParsingError.unexpectedToken(of: current.kind, at: current.range)
        }
        
        return try take()
    }
    
    mutating func skip() throws {
        current = peek
        peek = peek2
        peek2 = try lexer.next()
    }
    
    func `is`(of kind: Token.Kind) -> Bool {
        return current.kind == kind
    }
    
    mutating func nextParameterIndex() -> Int {
        defer { parameterIndex += 1 }
        return parameterIndex
    }
}
