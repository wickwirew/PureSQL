//
//  CollectIfParser.swift
//  
//
//  Created by Wes Wickwire on 10/9/24.
//

/// Will continuously execute the inner parser over and over collecting
/// the results into a final array if the token at the start and end of the execution
/// of the inner parser is one of the given tokens
struct CollectIfParser<Inner: Parser>: Parser {
    let checkFirst: Bool
    let tokens: Set<Token.Kind>
    let inner: Inner
    
    func parse(state: inout ParserState) throws -> [Inner.Output] {
        guard !checkFirst || tokens.contains(state.current.kind) else { return [] }
        
        var elements: [Inner.Output] = []
        
        repeat {
            try elements.append(inner.parse(state: &state))
        } while tokens.contains(state.current.kind)
        
        return elements
    }
}

extension Parser {
    func collect(if kinds: Set<Token.Kind>, checkFirst: Bool = false) -> CollectIfParser<Self> {
        return CollectIfParser(checkFirst: checkFirst, tokens: kinds, inner: self)
    }
}


