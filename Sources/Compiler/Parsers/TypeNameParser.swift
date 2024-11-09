//
//  TypeNameParser.swift
//
//
//  Created by Wes Wickwire on 10/9/24.
//

/// https://www.sqlite.org/syntax/type-name.html
struct TypeNameParser: Parser {
    func parse(state: inout ParserState) throws -> TypeName {
        let parser = SymbolParser()
        
        var name = try parser.parse(state: &state)
        
        while case let .symbol(s) = state.current.kind {
            let upperBound = state.current.range.upperBound
            try state.skip()
            name.append(" \(s)", upperBound: upperBound)
        }
        
        if try state.take(if: .openParen) {
            let parser = SignedNumberParser()
            
            let first = try parser.parse(state: &state)
            
            if try state.take(if: .comma) {
                let second = try parser.parse(state: &state)
                try state.consume(.closeParen)
                return TypeName(name: name, args: .two(first, second))
            } else {
                try state.consume(.closeParen)
                return TypeName(name: name, args: .one(first))
            }
        } else {
            return TypeName(name: name, args: nil)
        }
    }
}
