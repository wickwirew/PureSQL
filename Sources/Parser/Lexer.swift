//
//  Lexer.swift
//
//
//  Created by Wes Wickwire on 10/8/24.
//

import Schema
import Foundation

struct Lexer {
    let source: String
    var currentIndex: String.Index
    var peekIndex: String.Index
    
    static let hexDigits: Set<Character> = ["0","1","2","3","4","5","6","7","8","9","a","b",
                                            "c","d","e","f","A","B","C","D","E","F"]
    
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
        
        let peek = peek
        
        if current.isLetter {
            return parseWord()
        }
        
        if current == "0", peek == "x" || peek == "X" {
            return try hexLiteral()
        }
        
        if current.isNumber || (current == "." && peek?.isNumber == true) {
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
        case (":", _): return consumeSingle(of: .colon)
        case ("&", _): return consumeSingle(of: .ampersand)
        case ("$", _): return consumeSingle(of: .dollarSign)
        case ("?", _): return consumeSingle(of: .questionMark)
        case ("(", _): return consumeSingle(of: .openParen)
        case (")", _): return consumeSingle(of: .closeParen)
        case (",", _): return consumeSingle(of: .comma)
        case ("+", _): return consumeSingle(of: .plus)
        case ("-", _): return consumeSingle(of: .minus)
        case ("/", _): return consumeSingle(of: .divide)
        case ("%", _): return consumeSingle(of: .modulo)
        case ("<", _): return consumeSingle(of: .lt)
        case (">", _): return consumeSingle(of: .gt)
        case ("&", _): return consumeSingle(of: .ampersand)
        case ("|", _): return consumeSingle(of: .pipe)
        case ("^", _): return consumeSingle(of: .carrot)
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
        var hasSeenDecimal = current == "."
        
        consumeDigits()
        
        if current == "." {
            advance()
            hasSeenDecimal = true
        }
        
        consumeDigits()
        
        // Check if its in scientific notation
        if let maybeE = current, maybeE == "e" || maybeE == "E" {
            return try scientificNotation(mantissa: start..<currentIndex)
        }
        
        let range = start..<currentIndex
        let string = source[range]
        
        let kind: Token.Kind = if hasSeenDecimal {
            .double(try double(from: string, at: range))
        } else {
            .int(try integer(from: string, at: range))
        }
        
        return Token(kind: kind, range: range)
    }
    
    private mutating func scientificNotation(
        mantissa mantissaRange: Range<String.Index>
    ) throws -> Token {
        advance() // E or e
        
        if current?.isNumber == true {
            let exponentStart = currentIndex
            consumeDigits()
            return try scientificNotation(
                mantissa: mantissaRange,
                exponent: exponentStart..<currentIndex,
                isExpoinentPositive: true
            )
        } else {
            let isPositive: Bool
            if current == "+" {
                advance()
                isPositive = true
            } else if current == "-" {
                advance()
                isPositive = false
            } else {
                isPositive = true
            }
            
            let exponentStart = currentIndex
            consumeDigits()
            
            return try scientificNotation(
                mantissa: mantissaRange,
                exponent: exponentStart..<currentIndex,
                isExpoinentPositive: isPositive
            )
        }
    }
    
    private func scientificNotation(
        mantissa mantissaRange: Range<String.Index>,
        exponent exponentRange: Range<String.Index>,
        isExpoinentPositive: Bool
    ) throws -> Token {
        let mantissa = try double(from: source[mantissaRange], at: mantissaRange)
        let exponentUnsigned = try double(from: source[exponentRange], at: exponentRange)
        let exponent = isExpoinentPositive ? exponentUnsigned : -exponentUnsigned
        let value = mantissa * pow(10, exponent)
        return Token(kind: .double(value), range: mantissaRange.lowerBound..<exponentRange.upperBound)
    }
    
    private mutating func consumeDigits() {
        while let current, (current.isNumber || current == "_") {
            advance()
        }
    }
    
    private mutating func hexLiteral() throws -> Token {
        let tokenStart = currentIndex
        
        advance() // 0
        advance() // x or X
        
        let numberStart = currentIndex
        
        while let current, (Lexer.hexDigits.contains(current) || current == "_") {
            advance()
        }
        
        let numberRange = numberStart..<currentIndex
        
        guard let value = Int(source[numberRange], radix: 16) else {
            throw ParsingError(
                description: "Invalid hex number",
                sourceRange: tokenStart..<currentIndex
            )
        }
        
        return Token(kind: .hex(value), range: tokenStart..<currentIndex)
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
    
    private func integer<S: StringProtocol>(
        from source: S,
        at range: Range<String.Index>
    ) throws -> Int {
        guard let int = Int(source.replacingOccurrences(of: "_", with: "")) else {
            throw ParsingError(
                description: "Invalid integer '\(source)'",
                sourceRange: range
            )
        }
        
        return int
    }
    
    private func double<S: StringProtocol>(
        from source: S,
        at range: Range<String.Index>
    ) throws -> Double {
        guard let double = Double(source.replacingOccurrences(of: "_", with: "")) else {
            throw ParsingError(
                description: "Invalid double '\(source)'",
                sourceRange: range
            )
        }
        
        return double
    }
}
