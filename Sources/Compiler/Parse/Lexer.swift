//
//  Lexer.swift
//
//
//  Created by Wes Wickwire on 10/8/24.
//

import Foundation

/// Tokenizes the source token into tokens.
struct Lexer {
    /// The raw source SQL
    let source: String
    /// The current character we are considering consuming.
    var currentIndex: String.Index
    /// The character right after the current index
    var peekIndex: String.Index
    /// Holds any errors we encounter
    var diagnostics: Diagnostics
    /// The current line number, starting at 1 since IDEs dont start at 0
    var currentLine: Int = 1
    /// The current column number, starting at 1 since IDEs dont start at 0
    var currentColumn: Int = 1
    
    static let hexDigits: Set<Character> = [
        "0","1","2","3","4","5","6","7","8","9","a","b",
        "c","d","e","f","A","B","C","D","E","F"
    ]
    
    /// When we start consuming a token, we need the index, line and column
    /// numbers. This acts as a little box so we can hold onto one value
    /// before assembling it into the final `SourceLocation`
    struct Start {
        let index: String.Index
        let line: Int
        let column: Int
    }
    
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
    
    /// The current character we are considering consuming.
    private var current: Character? {
        guard currentIndex < source.endIndex else { return nil }
        return source[currentIndex]
    }
    
    /// The character after the `current` character
    private var peek: Character? {
        guard peekIndex < source.endIndex else { return nil }
        return source[peekIndex]
    }
    
    /// Token to represent the end of the file. e.g. `EOF`
    private var eof: Token {
        return Token(
            kind: .eof,
            location: SourceLocation(
                range: source.endIndex..<source.endIndex,
                line: currentLine,
                column: currentColumn
            )
        )
    }
    
    /// Gets the next token from the source.
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
            let start = startLocation()
            advance()
            advance()
            if self.current == ">" {
                advance()
                return Token(kind: .doubleArrow, location: location(from: start, to: peekIndex))
            } else {
                return Token(kind: .arrow, location: location(from: start, to: peekIndex))
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
        case ("\"", _): return parseEscapedIdentifier(closing: "\"")
        case ("[", _): return parseEscapedIdentifier(closing: "]")
        case ("`", _): return parseEscapedIdentifier(closing: "`")
        default:
            diagnostics.add(.init(
                "Unexpected character: '\(current)'",
                at: location(from: startLocation(), to: peekIndex)
            ))
            advance()
            return next()
        }
    }
    
    /// Moves the indices to the next characters
    private mutating func advance() {
        currentIndex = peekIndex
        
        if peekIndex < source.endIndex {
            peekIndex = source.index(after: peekIndex)
        }
        
        if current?.isNewline == true {
            currentLine += 1
            currentColumn = 0
        } else {
            currentColumn += 1
        }
    }
    
    // SQLite does not seem to really care what goes between the escape delimiters.
    // Table names will gladly take newlines and such.
    private mutating func parseEscapedIdentifier(closing: Character) -> Token {
        let tokenStart = startLocation()
        advance() // Opening
        let identifierStart = currentIndex
        
        while let current, current != closing {
            advance()
        }
        
        let identifierEnd = currentIndex
        
        // If the current is nil it the EOF, else its
        // our closing character.
        if current == nil {
            diagnostics.add(.init(
                "Unterminated escaped identifier",
                at: location(from: tokenStart)
            ))
        } else {
            advance()
        }
        
        let location = location(from: tokenStart)
        let identifierRange = identifierStart..<identifierEnd
        return Token(kind: .symbol(source[identifierRange]), location: location)
    }
    
    /// Parses out a word which can be either an identifier or keyword.
    private mutating func parseWord() -> Token {
        let start = startLocation()
        
        while let current, current.isLetter || current.isNumber || current == "_" {
            advance()
        }
        
        let location = location(from: start)
        return Token(kind: Token.Kind(word: source[location.range]), location: location)
    }
    
    private mutating func parseNumber() -> Token {
        let start = startLocation()
        var hasSeenDecimal = current == "."
        
        consumeDigits()
        
        if current == "." {
            advance()
            hasSeenDecimal = true
        }
        
        consumeDigits()
        
        // Check if its in scientific notation
        if let maybeE = current, maybeE == "e" || maybeE == "E" {
            return scientificNotation(
                mantissa: start.index..<currentIndex,
                start: start
            )
        }
        
        let location = location(from: start)
        let string = source[location.range]
        
        let kind: Token.Kind = if hasSeenDecimal {
            .double(double(from: string, at: location.range))
        } else {
            .int(integer(from: string, at: location.range))
        }
        
        return Token(kind: kind, location: location)
    }
    
    private mutating func scientificNotation(
        mantissa mantissaRange: Range<String.Index>,
        start: Start
    ) -> Token {
        advance() // E or e
        
        if current?.isNumber == true {
            let exponentStart = currentIndex
            consumeDigits()
            return scientificNotation(
                mantissa: mantissaRange,
                exponent: exponentStart..<currentIndex,
                isExpoinentPositive: true,
                start: start
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
                isExpoinentPositive: isPositive,
                start: start
            )
        }
    }
    
    private mutating func scientificNotation(
        mantissa mantissaRange: Range<String.Index>,
        exponent exponentRange: Range<String.Index>,
        isExpoinentPositive: Bool,
        start: Start
    ) -> Token {
        let mantissa = double(from: source[mantissaRange], at: mantissaRange)
        let exponentUnsigned = double(from: source[exponentRange], at: exponentRange)
        let exponent = isExpoinentPositive ? exponentUnsigned : -exponentUnsigned
        let value = mantissa * pow(10, exponent)
        return Token(
            kind: .double(value),
            location: location(
                from: start,
                to: exponentRange.upperBound
            )
        )
    }
    
    private mutating func consumeDigits() {
        while let current, current.isNumber || current == "_" {
            advance()
        }
    }
    
    private mutating func hexLiteral() -> Token {
        let tokenStart = startLocation()
        
        advance() // 0
        advance() // x or X
        
        let numberStart = currentIndex
        
        while let current, Lexer.hexDigits.contains(current) || current == "_" {
            advance()
        }
        
        let numberRange = numberStart..<currentIndex
        let location = location(from: tokenStart)
        
        guard let value = Int(source[numberRange], radix: 16) else {
            diagnostics.add(.init("Invalid hex number", at: location))
            return Token(kind: .hex(0), location: location)
        }
        
        return Token(kind: .hex(value), location: location)
    }
    
    private mutating func parseString() -> Token {
        let tokenStart = startLocation()
        advance()
        let stringStart = currentIndex
        
        while let current, current != "'" {
            advance()
        }
        
        let stringRange = stringStart..<currentIndex
        
        if current == "'" {
            advance()
        } else {
            diagnostics.add(.init("Unterminated string", at: location(from: tokenStart)))
        }
        
        return Token(kind: .string(source[stringRange]), location: location(from: tokenStart))
    }
    
    private mutating func skipWhitespace() {
        while let current, current.isWhitespace {
            advance()
        }
    }
    
    private mutating func consumeSingle(of kind: Token.Kind) -> Token {
        let start = startLocation()
        advance()
        return Token(kind: kind, location: location(from: start))
    }
    
    private mutating func consumeDouble(of kind: Token.Kind) -> Token {
        let start = startLocation()
        advance()
        advance()
        return Token(kind: kind, location: location(from: start))
    }
    
    private mutating func integer<S: StringProtocol>(
        from source: S,
        at range: Range<String.Index>
    ) -> Int {
        guard let int = Int(source.replacingOccurrences(of: "_", with: "")) else {
            diagnostics.add(.init(
                "Invalid integer '\(source)'",
                at: SourceLocation(
                    range: range,
                    line: currentLine,
                    column: currentColumn
                )
            ))
            return 0
        }
        
        return int
    }
    
    private mutating func double<S: StringProtocol>(
        from source: S,
        at range: Range<String.Index>
    ) -> Double {
        guard let double = Double(source.replacingOccurrences(of: "_", with: "")) else {
            diagnostics.add(.init(
                "Invalid double '\(source)'",
                at: SourceLocation(
                    range: range,
                    line: currentLine,
                    column: currentColumn
                )
            ))
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
        from start: Start,
        to upperBound: Substring.Index
    ) -> SourceLocation {
        return SourceLocation(
            range: start.index ..< upperBound,
            line: start.line,
            column: start.column
        )
    }
    
    private func location(
        from start: Start
    ) -> SourceLocation {
        return SourceLocation(
            range: start.index ..< currentIndex,
            line: start.line,
            column: start.column
        )
    }
    
    private func startLocation() -> Start {
        return Start(
            index: currentIndex,
            line: currentLine,
            column: currentColumn
        )
    }
}
