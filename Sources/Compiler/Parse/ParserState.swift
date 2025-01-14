//
//  ParserState.swift
//
//
//  Created by Wes Wickwire on 10/9/24.
//

struct ParserState {
    private var lexer: Lexer
    private(set) var current: Token
    private(set) var peek: Token
    private(set) var peek2: Token
    private var parameterIndex = 1
    private var namedParamIndices: [Substring: Int] = [:]
    var diagnostics = Diagnostics()
    	
    init(_ lexer: Lexer) {
        self.lexer = lexer
        self.current = self.lexer.next()
        self.peek = self.lexer.next()
        self.peek2 = self.lexer.next()
    }

    var range: Range<String.Index> {
        return current.range
    }
    
    func range(from range: borrowing Range<String.Index>) -> Range<String.Index> {
        return range.lowerBound..<current.range.upperBound
    }
    
    func range(from token: borrowing Token) -> Range<String.Index> {
        return token.range.lowerBound..<current.range.upperBound
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
    
    /// Consumes the next token and validates it is of the input kind
    mutating func consume(_ kind: Token.Kind) {
        guard current.kind == kind else {
            diagnostics.add(.unexpectedToken(of: current.kind, expected: kind, at: range))
            return
        }
        
        skip()
    }
    
    /// Consumes the next token and validates it is of the input kind
    mutating func take(_ kind: Token.Kind) -> Token {
        guard current.kind == kind else {
            diagnostics.add(.unexpectedToken(of: current.kind, expected: kind, at: range))
            return Token(kind: kind, range: current.range)
        }
        
        return take()
    }
    
    mutating func skip() {
        current = peek
        peek = peek2
        peek2 = lexer.next()
    }
    
    func `is`(of kind: Token.Kind) -> Bool {
        return current.kind == kind
    }
    
    mutating func indexForParam(named name: Substring) -> Int {
        if let existing = namedParamIndices[name] { return existing }
        let index = indexForUnnamedParam()
        namedParamIndices[name] = index
        return index
    }
    
    mutating func indexForUnnamedParam() -> Int {
        defer { parameterIndex += 1 }
        return parameterIndex
    }
    
    mutating func resetParameterIndex() {
        parameterIndex = 1
        namedParamIndices.removeAll(keepingCapacity: true)
    }
}
