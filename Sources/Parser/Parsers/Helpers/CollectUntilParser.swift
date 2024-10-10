//
//  CollectUntilParser.swift
//  
//
//  Created by Wes Wickwire on 10/9/24.
//

/// Will continuously execute the inner parser over and over collecting
/// the results into a final array until one of the specified tokens is hit
struct CollectUntilParser<Inner: Parser>: Parser {
    let tokens: Set<Token.Kind>
    let inner: Inner
    
    func parse(state: inout ParserState) throws -> [Inner.Output] {
        guard !tokens.contains(state.peek.kind) else { return [] }
        
        var elements: [Inner.Output] = []
        
        repeat {
            try elements.append(inner.parse(state: &state))
        } while !tokens.contains(state.peek.kind)
        
        return elements
    }
}

extension Parser {
    func collect(until kinds: Set<Token.Kind>) -> CollectUntilParser<Self> {
        return CollectUntilParser(tokens: kinds, inner: self)
    }
}

