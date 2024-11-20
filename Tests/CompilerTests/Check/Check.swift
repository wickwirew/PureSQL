//
//  Check.swift
//  SQL
//
//  Created by Wes Wickwire on 10/27/24.
//

import XCTest

@testable import Compiler

func check<P: Parser>(
    sqlFile: String,
    parser: P,
    prefix: String = "CHECK",
    file: StaticString = #filePath,
    line: UInt = #line
) throws where P.Output: Encodable {
    guard let url = Bundle.module.url(forResource: sqlFile, withExtension: "sql") else {
        XCTFail("Could not find SQL file named \(sqlFile)", file: file, line: line)
        return
    }
    
    let contents = try String(contentsOf: url)
    
    var state = try ParserState(Lexer(source: contents))
    var lines: [String] = []
    
    while state.current.kind != .eof {
        var emitter = CheckEmitter()
        try emitter.emit(parser.parse(state: &state), indent: 0)
        lines.append(contentsOf: emitter.lines)
    }
    
    try check(
        contents: contents,
        equalTo: lines.joined(separator: "\n"),
        prefix: prefix,
        file: file,
        line: line
    )
}

func check(
    contents: String,
    equalTo input: String,
    prefix: String = "CHECK",
    file: StaticString = #filePath,
    line: UInt = #line
) throws {
    var parser = CheckParser(contents: contents, prefix: prefix)
    let checks = parser.checks()
    assertChecks(checks, equalTo: input, file: file, line: line)
}

func assertChecks(
    _ checks: [String],
    equalTo input: String,
    file: StaticString = #filePath,
    line: UInt = #line
) {
    var checks = checks.makeIterator()
    // The hop to String then split again is to allow multiline inputs
    var input = input.split(separator: "\n").map{ $0.trimmingCharacters(in: .whitespaces) }.makeIterator()
    var index: Int = 0
    
    while true {
        let check = checks.next()
        let input = input.next()
        
        if check == nil && input == nil {
            return // At the end
        }
        
        guard let check else {
            XCTFail("'\(input ?? "")' does not exist in checks", file: file, line: line)
            return
        }
        
        guard let input else {
            XCTFail("'\(check)' does not exist in input", file: file, line: line)
            return
        }
        
        XCTAssertEqual(check, input, "Check #\(index + 1)", file: file, line: line)
        index += 1
    }
}

struct CheckParser {
    var characters: String.Iterator
    let prefix: String
    var current: Character?
    
    init(contents: String, prefix: String) {
        self.characters = contents.makeIterator()
        self.prefix = "\(prefix):"
        self.current = prefix.first
    }
    
    mutating func checks() -> [String] {
        var checks: [String] = []
        
        while let current {
            if current.isWhitespace {
                skipWhiteSpace()
                continue
            }
            
            guard current == prefix.first else {
                skipWord()
                continue
            }
            
            let word = take(until: \.isWhitespace)
            
            if word == prefix {
                skipWhiteSpace()
                checks.append(take(until: \.isNewline))
            }
        }
        
        return checks
    }
    
    private mutating func take(
        until predicate: (Character) -> Bool
    ) -> String {
        var result: String = ""
        
        while let current, !predicate(current) {
            result.append(current)
            advance()
        }
        
        return result
    }
    
    private mutating func skipWhiteSpace() {
        while let current, current.isWhitespace {
            advance()
        }
    }
    
    private mutating func skipWord() {
        while let current, !current.isWhitespace {
            advance()
        }
    }
    
    private mutating func advance() {
        current = characters.next()
    }
}

struct CheckEmitter {
    var lines: [String] = []
    
    mutating func emit(_ value: Any, for key: String? = nil, indent: Int) {
        if isPrimitive(value) {
            write(value, for: key, indent: indent)
        } else if value is Range<Substring.Index> {
            return // Skip ranges since it would be too much
        } else if let arr = value as? [Any] {
            for value in arr {
                emit(value, indent: indent + 1)
            }
        } else {
            write(key: "\(type(of: value))", indent: indent)
            
            let mirror = Mirror(reflecting: value)
            
            for child in mirror.children {
                emit(child.value, for: child.label, indent: indent + 1)
            }
        }
    }
    
    private func isPrimitive(_ value: Any) -> Bool {
        return switch value {
        case is Bool, is Int, is Int8, is Int16, is Int32, is Int64,
                is UInt, is UInt8, is UInt16, is UInt32, is UInt64,
            is Float, is Double, is String, is Any.Type: true
        default: false
        }
    }
    
    private mutating func write(_ value: Any, for key: String? = nil, indent: Int) {
        let indent = String(repeating: " ", count: indent * 2)
        
        if let key {
            lines.append("\(indent)\(uppersnakeCase(key)) \(value)")
        } else {
            lines.append("\(indent)\(value)")
        }
    }
    
    private mutating func write(key: String, indent: Int) {
        let key = uppersnakeCase(key)
        let indent = String(repeating: " ", count: indent * 2)
        lines.append("\(indent)\(key)")
    }
    
    private mutating func uppersnakeCase(_ value: String) -> String {
        var result = ""
        
        for c in value {
            if c.isUppercase && !result.isEmpty {
                result += "_"
            }
            
            result += c.uppercased()
        }
        
        return result
    }
}
