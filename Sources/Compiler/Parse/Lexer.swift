//
//  Lexer.swift
//
//
//  Created by Wes Wickwire on 10/8/24.
//

import Foundation

struct Lexer {
    let source: String
    var currentIndex: String.Index
    var peekIndex: String.Index
    var diagnostics: Diagnostics
    
    static let hexDigits: Set<Character> = ["0","1","2","3","4","5","6","7","8","9","a","b",
                                            "c","d","e","f","A","B","C","D","E","F"]
    
    init(
        source: String,
        diagnostics: Diagnostics = Diagnostics()
    ) {
        self.source = source
        self.currentIndex = source.startIndex
        self.peekIndex = currentIndex < source.endIndex
            ? source.index(after: currentIndex)
            : currentIndex
        self.diagnostics = diagnostics
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
        return Token(
            kind: .eof,
            location: SourceLocation(
                range: source.endIndex..<source.endIndex
            )
        )
    }
    
    mutating func next() -> Token {
        skipWhitespace()
        
        guard let current else {
            return eof
        }
        
        let peek = peek
        
        if current.isLetter {
            return parseWord()
        }
        
        if current == "0", peek == "x" || peek == "X" {
            return hexLiteral()
        }
        
        if current.isNumber || (current == "." && peek?.isNumber == true) {
            return parseNumber()
        }
        
        switch (current, peek) {
        case ("*", "/"): return consumeDouble(of: .starForwardSlash)
        case ("/", "*"): return consumeDouble(of: .forwardSlashStar)
        case ("<", "<"): return consumeDouble(of: .shiftLeft)
        case ("<", "="): return consumeDouble(of: .lte)
        case (">", ">"): return consumeDouble(of: .shiftRight)
        case (">", "="): return consumeDouble(of: .gte)
        case ("|", "|"): return consumeDouble(of: .concat)
        case ("-", "-"):
            skipSingleLineComment()
            return next()
        case ("=", "="): return consumeDouble(of: .doubleEqual)
        case ("!", "="): return consumeDouble(of: .notEqual)
        case ("<", ">"): return consumeDouble(of: .notEqual2)
        case ("-", ">"):
            advance()
            advance()
            if self.current == ">" {
                advance()
                return Token(kind: .doubleArrow, location: location(from: currentIndex, to: peekIndex))
            } else {
                return Token(kind: .arrow, location: location(from: currentIndex, to: peekIndex))
            }
        case ("*", _): return consumeSingle(of: .star)
        case ("=", _): return consumeSingle(of: .equal)
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
        case ("@", _): return consumeSingle(of: .at)
        case ("|", _): return consumeSingle(of: .pipe)
        case ("^", _): return consumeSingle(of: .carrot)
        case ("~", _): return consumeSingle(of: .tilde)
        case ("'", _): return parseString()
        default:
            diagnostics.add(.init("Unexpected character: '\(current)'", at: location(from: currentIndex, to: peekIndex)))
            advance()
            return next()
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
        
        while let current, current.isLetter || current.isNumber || current == "_" {
            advance()
        }
        
        let location = location(from: start, to: currentIndex)
        return Token(kind: Token.Kind(word: source[location.range]), location: location)
    }
    
    private mutating func parseNumber() -> Token {
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
            return scientificNotation(mantissa: start..<currentIndex)
        }
        
        let location = location(from: start, to: currentIndex)
        let string = source[location.range]
        
        let kind: Token.Kind = if hasSeenDecimal {
            .double(double(from: string, at: location.range))
        } else {
            .int(integer(from: string, at: location.range))
        }
        
        return Token(kind: kind, location: location)
    }
    
    private mutating func scientificNotation(
        mantissa mantissaRange: Range<String.Index>
    ) -> Token {
        advance() // E or e
        
        if current?.isNumber == true {
            let exponentStart = currentIndex
            consumeDigits()
            return scientificNotation(
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
            
            return scientificNotation(
                mantissa: mantissaRange,
                exponent: exponentStart..<currentIndex,
                isExpoinentPositive: isPositive
            )
        }
    }
    
    private mutating func scientificNotation(
        mantissa mantissaRange: Range<String.Index>,
        exponent exponentRange: Range<String.Index>,
        isExpoinentPositive: Bool
    ) -> Token {
        let mantissa = double(from: source[mantissaRange], at: mantissaRange)
        let exponentUnsigned = double(from: source[exponentRange], at: exponentRange)
        let exponent = isExpoinentPositive ? exponentUnsigned : -exponentUnsigned
        let value = mantissa * pow(10, exponent)
        return Token(
            kind: .double(value),
            location: location(from: mantissaRange.lowerBound, to: exponentRange.upperBound)
        )
    }
    
    private mutating func consumeDigits() {
        while let current, current.isNumber || current == "_" {
            advance()
        }
    }
    
    private mutating func hexLiteral() -> Token {
        let tokenStart = currentIndex
        
        advance() // 0
        advance() // x or X
        
        let numberStart = currentIndex
        
        while let current, Lexer.hexDigits.contains(current) || current == "_" {
            advance()
        }
        
        let numberRange = numberStart..<currentIndex
        let location = location(from: tokenStart, to: currentIndex)
        
        guard let value = Int(source[numberRange], radix: 16) else {
            diagnostics.add(.init("Invalid hex number", at: location))
            return Token(kind: .hex(0), location: location)
        }
        
        return Token(kind: .hex(value), location: location)
    }
    
    private mutating func parseString() -> Token {
        let tokenStart = currentIndex
        advance()
        let start = currentIndex
        
        while let current, current != "'" {
            advance()
        }
        
        let stringRange = start..<currentIndex
        
        if current == "'" {
            advance()
        } else {
            diagnostics.add(.init("Unterminated string", at: location(from: start, to: currentIndex)))
        }
        
        return Token(kind: .string(source[stringRange]), location: location(from: tokenStart, to: currentIndex))
    }
    
    private mutating func skipWhitespace() {
        while let current, current.isWhitespace {
            advance()
        }
    }
    
    private mutating func consumeSingle(of kind: Token.Kind) -> Token {
        let start = currentIndex
        advance()
        return Token(kind: kind, location: location(from: start, to: currentIndex))
    }
    
    private mutating func consumeDouble(of kind: Token.Kind) -> Token {
        let start = currentIndex
        advance()
        advance()
        return Token(kind: kind, location: location(from: start, to: currentIndex))
    }
    
    private mutating func integer<S: StringProtocol>(
        from source: S,
        at range: Range<String.Index>
    ) -> Int {
        guard let int = Int(source.replacingOccurrences(of: "_", with: "")) else {
            diagnostics.add(.init("Invalid integer '\(source)'", at: SourceLocation(range: range)))
            return 0
        }
        
        return int
    }
    
    private mutating func double<S: StringProtocol>(
        from source: S,
        at range: Range<String.Index>
    ) -> Double {
        guard let double = Double(source.replacingOccurrences(of: "_", with: "")) else {
            diagnostics.add(.init("Invalid double '\(source)'", at: SourceLocation(range: range)))
            return 0
        }
        
        return double
    }
    
    private mutating func skipSingleLineComment() {
        advance()
        advance()
        
        while let current, !current.isNewline {
            advance()
        }
    }
    
    private func location(
        from lowerBound: Substring.Index,
        to upperBound: Substring.Index
    ) -> SourceLocation {
        return SourceLocation(range: lowerBound ..< upperBound)
    }
}
