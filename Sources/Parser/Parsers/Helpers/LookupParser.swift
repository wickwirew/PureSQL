//
//  LookupParser.swift
//  
//
//  Created by Wes Wickwire on 10/9/24.
//

/// A parser that will lookup the current token's `kind` in a dictionary
/// and return the result. If no entry is found, it will return an error saying it
/// expected one of the given keys
struct LookupParser<Output>: Parser {
    let lookup: [Token.Kind: Output]
    
    init(_ lookup: [Token.Kind : Output]) {
        self.lookup = lookup
    }
    
    func parse(state: inout ParserState) throws -> Output {
        let token = try state.next()
        
        guard let output = lookup[token.kind] else {
            throw ParsingError.expected(Array(lookup.keys), at: token.range)
        }
        
        return output
    }
}
