//
//  Parser2.swift
//
//
//  Created by Wes Wickwire on 10/9/24.
//

protocol Parser2 {
    associatedtype Output
    func parse(tokens: inout Tokens) throws -> Output
}

struct Tokens {
    private var lexer: Lexer
    private(set) var peek: Token
    
    init(_ lexer: Lexer) throws {
        self.lexer = lexer
        self.peek = try self.lexer.next()
    }
}

extension Tokens {
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
    
    /// Skips the next token and validates it is of the input kind
    mutating func skip(_ kind: Token.Kind) throws {
        guard peek.kind == kind else {
            throw ParsingError.unexpectedToken(of: peek.kind, at: peek.range)
        }
        
        peek = try lexer.next()
    }
}


struct ParenthesisParser<Inner: Parser2>: Parser2 {
    let inner: Inner
    
    init(_ inner: Inner) {
        self.inner = inner
    }
    
    func parse(tokens: inout Tokens) throws -> Inner.Output {
        try tokens.skip(.openParen)
        let output = try inner.parse(tokens: &tokens)
        try tokens.skip(.closeParen)
        return output
    }
}

struct CommaSeparatedParser<Element: Parser2>: Parser2 {
    let element: Element
    
    init(_ element: Element) {
        self.element = element
    }
    
    func parse(tokens: inout Tokens) throws -> [Element.Output] {
        var elements: [Element.Output] = []
        
        repeat {
            elements.append(try element.parse(tokens: &tokens))
        } while try tokens.next(if: .comma)
        
        return elements
    }
}

extension Parser2 {
    func commaSeparated() -> CommaSeparatedParser<Self> {
        return CommaSeparatedParser(self)
    }
    
    func inParenthesis() -> ParenthesisParser<Self> {
        return ParenthesisParser(self)
    }
}

import Schema

struct SymbolParser: Parser2 {
    func parse(tokens: inout Tokens) throws -> Substring {
        let token = try tokens.next()
        
        guard case let .symbol(symbol) = token.kind else {
            throw ParsingError.expectedSymbol(at: token.range)
        }
        
        return symbol
    }
}

struct OrderParser: Parser2 {
    func parse(tokens: inout Tokens) throws -> Order? {
        if try tokens.next(if: .asc) {
            return .asc
        } else if try tokens.next(if: .desc) {
            return .desc
        } else {
            return nil
        }
    }
}

struct ColumnListParser: Parser2 {
    func parse(tokens: inout Tokens) throws -> [Substring] {
        try SymbolParser()
            .commaSeparated()
            .inParenthesis()
            .parse(tokens: &tokens)
    }
}
