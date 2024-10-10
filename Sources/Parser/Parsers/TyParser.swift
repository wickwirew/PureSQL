//
//  TyParser.swift
//
//
//  Created by Wes Wickwire on 10/9/24.
//

import Schema

/// Parses out a type. This will convert the type name to a concrete
/// known type that will be easier to use later in the process.
/// 
/// https://www.sqlite.org/syntax/type-name.html
struct TyParser: Parser {
    func parse(state: inout ParserState) throws -> Ty {
        let range = state.range
        let name = try SymbolParser().parse(state: &state)
        
        if state.is(of: .openParen) {
            let numbers = try SignedNumberParser()
                .commaSeparated()
                .inParenthesis()
                .parse(state: &state)
            
            let first = numbers.first
            let second = numbers.count > 1 ? numbers[1] : nil
            return try tyOrThrow(at: range, name: name, with: first, and: second)
        } else {
            return try tyOrThrow(at: range, name: name)
        }
    }
    
    func tyOrThrow(
        at range: Range<String.Index>,
        name: Substring,
        with first: Numeric? = nil,
        and second: Numeric? = nil
    ) throws -> Ty {
        guard let ty = Ty(name: name, with: first, and: second) else {
            throw ParsingError.unknown(type: name, at: range)
        }
        
        return ty
    }
}
