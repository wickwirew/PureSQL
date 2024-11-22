//
//  SeparatedParser.swift
//  
//
//  Created by Wes Wickwire on 10/9/24.
//

struct SeparatedParser<Element: Parser>: Parser {
    let separator: Token.Kind
    let other: Token.Kind?
    let element: Element
    
    init(separator: Token.Kind, and other: Token.Kind?, _ element: Element) {
        self.separator = separator
        self.other = other
        self.element = element
    }
    
    func parse(state: inout ParserState) throws -> [Element.Output] {
        var elements: [Element.Output] = []
        
        repeat {
            elements.append(try element.parse(state: &state))
        } while try shouldRepeat(state: &state)
        
        return elements
    }

    private func shouldRepeat(state: inout ParserState) throws -> Bool {
        if let other, try state.take(if: separator, and: other) {
            return state.current.kind != .eof
        } else if try state.take(if: separator) {
            return state.current.kind != .eof
        } else {
            return false
        }
    }
}

extension Parser {
    func commaSeparated() -> SeparatedParser<Self> {
        return SeparatedParser(separator: .comma, and: nil, self)
    }
    
    func semiColonSeparated() -> SeparatedParser<Self> {
        return SeparatedParser(separator: .semiColon, and: nil, self)
    }
    
    func separated(by separator: Token.Kind, and other: Token.Kind? = nil) -> SeparatedParser<Self> {
        return SeparatedParser(separator: separator, and: other, self)
    }
}
