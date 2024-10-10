//
//  MapParser.swift
//  
//
//  Created by Wes Wickwire on 10/9/24.
//

/// Parser that works like any map function in Swift.
/// After executing the base parser it will then run the
/// value through a transform function
struct MapParser<Base: Parser, Output>: Parser {
    let base: Base
    let transform: (Base.Output) throws -> Output
    
    func parse(state: inout ParserState) throws -> Output {
        try transform(base.parse(state: &state))
    }
}

extension Parser {
    func map<New>(_ transform: @escaping (Output) throws -> New) -> MapParser<Self, New> {
        return MapParser(base: self, transform: transform)
    }
}
