//
//  SeparatedParser.swift
//  
//
//  Created by Wes Wickwire on 10/9/24.
//

public struct SeparatedParser<Element: Parser>: Parser {
    let separator: Token.Kind
    let element: Element
    
    init(separator: Token.Kind, _ element: Element) {
        self.separator = separator
        self.element = element
    }
    
    public func parse(state: inout ParserState) throws -> [Element.Output] {
        var elements: [Element.Output] = []
        
        repeat {
            elements.append(try element.parse(state: &state))
        } while try state.next(if: separator)
        
        return elements
    }
}

extension Parser {
    public func commaSeparated() -> SeparatedParser<Self> {
        return SeparatedParser(separator: .comma, self)
    }
    
    public func semiColonSeparated() -> SeparatedParser<Self> {
        return SeparatedParser(separator: .semiColon, self)
    }
}
