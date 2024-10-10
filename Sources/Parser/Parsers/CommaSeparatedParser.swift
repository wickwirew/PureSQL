//
//  CommaSeparatedParser.swift
//  
//
//  Created by Wes Wickwire on 10/9/24.
//

struct CommaSeparatedParser<Element: Parser>: Parser {
    let element: Element
    
    init(_ element: Element) {
        self.element = element
    }
    
    func parse(state: inout ParserState) throws -> [Element.Output] {
        var elements: [Element.Output] = []
        
        repeat {
            elements.append(try element.parse(state: &state))
        } while try state.next(if: .comma)
        
        return elements
    }
}

extension Parser {
    func commaSeparated() -> CommaSeparatedParser<Self> {
        return CommaSeparatedParser(self)
    }
}
