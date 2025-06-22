//
//  ParserState.swift
//
//
//  Created by Wes Wickwire on 10/9/24.
//

struct ParserState {
    private(set) var lexer: Lexer
    private(set) var previous: Token?
    private(set) var current: Token
    private(set) var peek: Token
    private(set) var peek2: Token
    private var parameterIndex = 1
    private var namedParamIndices: [BindParameterSyntax.Kind: Int] = [:]
    var diagnostics = Diagnostics()
    private var syntaxCounter = 0
    
    init(_ lexer: Lexer) {
        self.lexer = lexer
        self.current = self.lexer.next()
        self.peek = self.lexer.next()
        self.peek2 = self.lexer.next()
    }

    var location: SourceLocation {
        return current.location
    }
    
    /// Returns the source location from the starting `range` up to, but not
    /// including the `current` token of the parser
    func location(from range: borrowing SourceLocation) -> SourceLocation {
        return range.upTo(current.location)
    }
    
    /// Returns the source location from the starting `token` up to, but not
    /// including the `current` token of the parser
    func location(from token: borrowing Token) -> SourceLocation {
        return token.location.upTo(current.location)
    }
    
    func skippingOne() -> ParserState {
        var copy = self
        copy.skip()
        return copy
    }
    
    /// Gets the next token in the source stream
    mutating func take() -> Token {
        let result = current
        skip()
        return result
    }
    
    /// Gets the next token if it is of the input kind
    mutating func take(if kind: Token.Kind) -> Bool {
        guard current.kind == kind else { return false }
        skip()
        return true
    }
    
    /// Consumes the next token and validates it is of the input kind
    mutating func take(if kind: Token.Kind, or other: Token.Kind) -> Bool {
        guard current.kind == kind || current.kind == other else {
            return false
        }
        
        skip()
        return true
    }
    
    /// Consumes the next token and validates it is of the input kind
    mutating func take(if kind: Token.Kind, and other: Token.Kind) -> Bool {
        guard current.kind == kind, peek.kind == other else {
            return false
        }
        
        skip()
        skip()
        return true
    }
    
    /// Consumes the next token and validates it is of the input `kind`
    mutating func take(_ kind: Token.Kind) -> Token {
        guard current.kind == kind else {
            diagnostics.add(.unexpectedToken(of: current.kind, expected: kind, at: location))
            return Token(kind: kind, location: current.location)
        }
        
        return take()
    }
    
    /// Skips the current token and validates its the correct `kind`.
    /// If its not a diagnostic will be emitted and the token will not be skipped.
    mutating func skip(_ kind: Token.Kind) {
        if current.kind != kind {
            diagnostics.add(.unexpectedToken(of: current.kind, expected: kind, at: location))
            return
        }
        
        skip()
    }
    
    /// Skips the current token if it is the `kind`
    mutating func skip(if kind: Token.Kind) {
        guard current.kind == kind else { return }
        skip()
    }
    
    /// Skips to the next token
    mutating func skip() {
        previous = current
        current = peek
        peek = peek2
        peek2 = lexer.next()
    }
    
    /// Whether or not the current token is of the input `kind`
    func `is`(of kind: Token.Kind) -> Bool {
        return current.kind == kind
    }
    
    mutating func indexForParam(_ kind: BindParameterSyntax.Kind) -> Int {
        switch kind {
        case .questionMark:
            defer { parameterIndex += 1 }
            return parameterIndex
        case .number(let n):
            return n
        case .colon, .at, .tcl:
            if let existing = namedParamIndices[kind] { return existing }
            defer { parameterIndex += 1 }
            let index = parameterIndex
            namedParamIndices[kind] = index
            return index
        }
    }
    
    mutating func resetParameterIndex() {
        parameterIndex = 1
        namedParamIndices.removeAll(keepingCapacity: true)
    }
    
    mutating func nextId() -> SyntaxId {
        defer { syntaxCounter += 1 }
        return SyntaxId(syntaxCounter)
    }
}
