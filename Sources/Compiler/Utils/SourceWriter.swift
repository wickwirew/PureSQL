//
//  SourceWriter.swift
//  Feather
//
//  Created by Wes Wickwire on 6/8/25.
//

final class SourceWriter {
    private var currentIndent = 0
    private var segments: [Segment] = []
    private var currentCharacterCount = 0
    
    typealias Builder = () -> Void
    
    enum Segment {
        case string(String)
        case substring(Substring)
        case newline
    }
    
    func write(_ string: String) {
        segments.append(.string(string))
        currentCharacterCount += string.count
    }
    
    func write(_ substring: Substring) {
        segments.append(.substring(substring))
        currentCharacterCount += substring.count
    }
    
    func write(line string: String) {
        newline()
        write(string)
    }
    
    func write(line substring: Substring) {
        newline()
        write(substring)
    }
    
    func write(_ first: String, _ rest: String...) {
        write(first)
        for string in rest {
            write(string)
        }
    }
    
    func write(line first: String, _ rest: String...) {
        write(line: first)
        for string in rest {
            write(string)
        }
    }
    
    func write(_ first: Substring, _ rest: Substring...) {
        write(first)
        for string in rest {
            write(string)
        }
    }
    
    func blankLine() {
        write(line: "")
    }
    
    func newline() {
        segments.append(.newline)
        segments.append(.string(String(repeating: "    ", count: currentIndent)))
        currentCharacterCount += 1 + (4 * currentIndent)
    }
    
    func indent() {
        currentIndent += 1
    }
    
    func unindent() {
        currentIndent -= 1
    }
    
    func indented(_ builder: Builder) {
        indent()
        builder()
        unindent()
    }
    
    func wrapped(in opening: String, closing: String, builder: Builder) {
        write(opening)
        indent()
        builder()
        unindent()
        write(line: closing)
    }
    
    func parens(builder: Builder) {
        wrapped(in: "(", closing: ")", builder: builder)
    }
    
    func braces(builder: Builder) {
        wrapped(in: "{", closing: "}", builder: builder)
    }
    
    func brackets(builder: Builder) {
        wrapped(in: "[", closing: "]", builder: builder)
    }
    
    func commaSeparated<Elements: Collection>(
        _ elements: Elements,
        builder: (Elements.Element) -> Void
    ) {
        for (position, element) in elements.positional() {
            builder(element)
            
            if !position.isLast {
                write(",")
            }
        }
    }
    
    func commaSeparated<Elements: Collection>(
        _ elements: Elements
    ) where Elements.Element == String {
        for (position, element) in elements.positional() {
            write(element)
            
            if !position.isLast {
                write(",")
            }
        }
    }
    
    func reset() {
        currentIndent = 0
        segments = []
        currentCharacterCount = 0
    }
}

extension SourceWriter: CustomStringConvertible {
    var description: String {
        var result: String = ""
        result.reserveCapacity(currentCharacterCount)
        
        for segment in segments {
            switch segment {
            case .string(let string):
                result += string
            case .substring(let substring):
                result += substring
            case .newline:
                result += "\n"
            }
        }
        
        return result
    }
}
