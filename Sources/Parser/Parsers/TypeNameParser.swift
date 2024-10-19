//
//  TypeNameParser.swift
//
//
//  Created by Wes Wickwire on 10/9/24.
//

import Schema

/// https://www.sqlite.org/syntax/type-name.html
struct TypeNameParser: Parser {
    func parse(state: inout ParserState) throws -> TypeName {
        let parser = SymbolParser()
        
        var name = try String(parser.parse(state: &state))
        
        while case let .symbol(s) = state.current.kind {
            try state.skip()
            name.append(" \(s)")
        }
        
        if try state.take(if: .openParen) {
            let parser = SignedNumberParser()
            
            let first = try parser.parse(state: &state)
            
            if try state.take(if: .comma) {
                let second = try parser.parse(state: &state)
                try state.take(.closeParen)
                return TypeName(name: name, args: .two(first, second))
            } else {
                try state.take(.closeParen)
                return TypeName(name: name, args: .one(first))
            }
        } else {
            return TypeName(name: name, args: nil)
        }
    }
}
