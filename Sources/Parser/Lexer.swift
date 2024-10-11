//
//  Lexer.swift
//
//
//  Created by Wes Wickwire on 10/8/24.
//

import Schema

struct Lexer {
    let source: String
    var currentIndex: String.Index
    var peekIndex: String.Index
    
    init(source: String) {
        self.source = source
        self.currentIndex = source.startIndex
        self.peekIndex = currentIndex < source.endIndex
            ? source.index(after: currentIndex)
            : currentIndex
    }
    
    private var current: Character? {
        guard currentIndex < source.endIndex else { return nil }
        return source[currentIndex]
    }
    
    private var peek: Character? {
        guard peekIndex < source.endIndex else { return nil }
        return source[peekIndex]
    }
    
    private var eof: Token {
        return Token(kind: .eof, range: source.endIndex..<source.endIndex)
    }
    
    mutating func next() throws -> Token {
        skipWhitespace()
        
        guard let current else {
            return eof
        }
        
        if current.isLetter {
            return parseWord()
        }
        
        if current.isNumber {
            return try parseNumber()
        }
        
        switch (current, peek) {
        case ("*", "/"): return consumeDouble(of: .starForwardSlash)
        case ("/", "*"): return consumeDouble(of: .forwardSlashStar)
        case ("<", "<"): return consumeDouble(of: .shiftLeft)
        case ("<", "="): return consumeDouble(of: .lte)
        case (">", ">"): return consumeDouble(of: .shiftRight)
        case (">", "="): return consumeDouble(of: .gte)
        case ("|", "|"): return consumeDouble(of: .concat)
        case ("-", "-"): return consumeDouble(of: .dashDash)
        case ("=", "="): return consumeDouble(of: .doubleEqual)
        case ("!", "="): return consumeDouble(of: .notEqual)
        case ("<", ">"): return consumeDouble(of: .notEqual)
        case ("-", ">"):
            advance()
            advance()
            if self.current == ">" {
                advance()
                return Token(kind: .doubleArrow, range: currentIndex..<peekIndex)
            } else {
                return Token(kind: .arrow, range: currentIndex..<peekIndex)
            }
        case ("*", _): return consumeSingle(of: .star)
        case (".", _): return consumeSingle(of: .dot)
        case (";", _): return consumeSingle(of: .semiColon)
        case ("(", _): return consumeSingle(of: .openParen)
        case (")", _): return consumeSingle(of: .closeParen)
        case (",", _): return consumeSingle(of: .comma)
        case ("+", _): return consumeSingle(of: .plus)
        case ("-", _): return consumeSingle(of: .minus)
        case ("/", _): return consumeSingle(of: .divide)
        case ("%", _): return consumeSingle(of: .modulo)
        case ("<", _): return consumeSingle(of: .lt)
        case (">", _): return consumeSingle(of: .gt)
        case ("&", _): return consumeSingle(of: .bitwiseAnd)
        case ("|", _): return consumeSingle(of: .bitwiseOr)
        case ("^", _): return consumeSingle(of: .bitwiseXor)
        case ("~", _): return consumeSingle(of: .tilde)
        case ("'", _): return try parseString()
        default:
            throw ParsingError(
                description: "Unexpected character: '\(current)'",
                sourceRange: currentIndex..<currentIndex
            )
        }
    }
    
    private mutating func advance() {
        currentIndex = peekIndex
        
        if peekIndex < source.endIndex {
            peekIndex = source.index(after: peekIndex)
        }
    }
    
    private mutating func parseWord() -> Token {
        let start = currentIndex
        
        while let current, (current.isLetter || current.isNumber || current == "_") {
            advance()
        }
        
        let range = start..<currentIndex
        return Token(kind: Token.Kind(word: source[range]), range: range)
    }
    
    private mutating func parseNumber() throws -> Token {
        let start = currentIndex
        
        while let current, (current.isNumber || (current == "." && peek?.isNumber == true)) {
            advance()
        }
        
        let range = start..<currentIndex
        return Token(kind: .numeric(Numeric(source[range]) ?? 0), range: range)
    }
    
    private mutating func parseString() throws -> Token {
        let tokenStart = currentIndex
        advance()
        let start = currentIndex
        
        while let current, current != "'" {
            advance()
        }
        
        let stringRange = start..<currentIndex
        
        guard current == "'" else {
            throw ParsingError(
                description: "Unterminated string",
                sourceRange: start..<currentIndex
            )
        }
        
        advance()
        return Token(kind: .string(source[stringRange]), range: tokenStart..<currentIndex)
    }
    
    private mutating func skipWhitespace() {
        while let current, current.isWhitespace {
            advance()
        }
    }
    
    private mutating func consumeSingle(of kind: Token.Kind) -> Token {
        let start = currentIndex
        advance()
        return Token(kind: kind, range: start..<currentIndex)
    }
    
    private mutating func consumeDouble(of kind: Token.Kind) -> Token {
        let start = currentIndex
        advance()
        advance()
        return Token(kind: kind, range: start..<currentIndex)
    }
}
