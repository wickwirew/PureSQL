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
) throws where P.Output: Verifiable {
    guard let url = Bundle.module.url(forResource: sqlFile, withExtension: "sql") else {
        XCTFail("Could not find SQL file named \(sqlFile)", file: file, line: line)
        return
    }
    
    let contents = try String(contentsOf: url)
    
    var state = try ParserState(Lexer(source: contents))
    var output: [P.Output] = []
    
    while state.current.kind != .eof {
        try output.append(parser.parse(state: &state))
    }
    
    try check(
        contents: contents,
        equalTo: output
            .map(\.verification.description)
            .joined(separator: "\n"),
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
