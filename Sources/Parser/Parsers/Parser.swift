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

struct ParserState {
    private var lexer: Lexer
    private(set) var peek: Token
    
    init(_ lexer: Lexer) throws {
        self.lexer = lexer
        self.peek = try self.lexer.next()
    }
}

extension ParserState {
    var range: Range<String.Index> {
        return peek.range
    }
    
    /// Gets the next token in the source stream
    mutating func next() throws -> Token {
        let result = peek
        peek = try lexer.next()
        return result
    }
    
    /// Gets the next token if it is of the input kind
    mutating func next(if kind: Token.Kind) throws -> Bool {
        guard peek.kind == kind else { return false }
        peek = try lexer.next()
        return true
    }
    
    /// Consumes the next token and validates it is of the input kind
    mutating func take(_ kind: Token.Kind) throws {
        guard peek.kind == kind else {
            throw ParsingError.unexpectedToken(of: peek.kind, at: peek.range)
        }
        
        peek = try lexer.next()
    }
    
    mutating func skip() throws {
        peek = try lexer.next()
    }
    
    /// Consumes the next token and validates it is of the input kind
    mutating func take(if kind: Token.Kind, or other: Token.Kind) throws -> Bool {
        guard peek.kind == kind || peek.kind == other else {
            return false
        }
        
        peek = try lexer.next()
        return true
    }
    
    func `is`(of kind: Token.Kind) -> Bool {
        return peek.kind == kind
    }
}
