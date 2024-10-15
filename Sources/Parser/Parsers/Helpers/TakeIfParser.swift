//
//  TakeIfParser.swift
//
//
//  Created by Wes Wickwire on 10/9/24.
//

/// Will only execute the inner parser if the token kind matches the input
struct TakeIfParser<Inner: Parser>: Parser {
    let inner: Inner
    let check: (Token.Kind) -> Bool
    
    
    func parse(state: inout ParserState) throws -> Inner.Output? {
        guard check(state.current.kind) else { return nil }
        return try inner.parse(state: &state)
    }
}

extension Parser {
    func take(if kind: Token.Kind) -> TakeIfParser<Self> {
        return TakeIfParser(inner: self) { $0 == kind }
    }
    
    func take(ifNot kind: Token.Kind) -> TakeIfParser<Self> {
        return TakeIfParser(inner: self) { $0 != kind }
    }
}
