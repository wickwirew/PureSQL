//
//  TakeIfParser.swift
//  
//
//  Created by Wes Wickwire on 10/9/24.
//

/// Will only execute the inner parser if the token kind matches the input
struct TakeIfParser<Inner: Parser>: Parser {
    let required: Token.Kind
    let inner: Inner
    
    func parse(state: inout ParserState) throws -> Inner.Output? {
        guard state.is(of: required) else { return nil }
        return try inner.parse(state: &state)
    }
}

extension Parser {
    func take(if kind: Token.Kind) -> TakeIfParser<Self> {
        return TakeIfParser(required: kind, inner: self)
    }
}
