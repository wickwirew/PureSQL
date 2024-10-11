//
//  SeparatedParser.swift
//  
//
//  Created by Wes Wickwire on 10/9/24.
//

struct SeparatedParser<Element: Parser>: Parser {
    let separator: Token.Kind
    let element: Element
    
    init(separator: Token.Kind, _ element: Element) {
        self.separator = separator
        self.element = element
    }
    
    func parse(state: inout ParserState) throws -> [Element.Output] {
        var elements: [Element.Output] = []
        
        repeat {
            elements.append(try element.parse(state: &state))
        } while try state.take(if: separator)
        
        return elements
    }
}

extension Parser {
    func commaSeparated() -> SeparatedParser<Self> {
        return SeparatedParser(separator: .comma, self)
    }
    
    func semiColonSeparated() -> SeparatedParser<Self> {
        return SeparatedParser(separator: .semiColon, self)
    }
}
