//
//  ParenthesisParser.swift
//  
//
//  Created by Wes Wickwire on 10/9/24.
//

import Foundation

struct ParenthesisParser<Inner: Parser>: Parser {
    let inner: Inner
    
    init(_ inner: Inner) {
        self.inner = inner
    }
    
    func parse(state: inout ParserState) throws -> Inner.Output {
        try state.consume(.openParen)
        let output = try inner.parse(state: &state)
        try state.consume(.closeParen)
        return output
    }
}

extension Parser {
    func inParenthesis() -> ParenthesisParser<Self> {
        return ParenthesisParser(self)
    }
}
