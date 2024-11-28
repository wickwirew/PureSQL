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
    dump: Bool = false,
    file: StaticString = #filePath,
    line: UInt = #line
) throws {
    try check(
        sqlFile: sqlFile,
        parse: parser.parse,
        prefix: prefix,
        dump: dump,
        file: file,
        line: line
    )
}

func check<Output>(
    sqlFile: String,
    parse: (inout ParserState) throws -> Output,
    prefix: String = "CHECK",
    dump: Bool = false,
    file: StaticString = #filePath,
    line: UInt = #line
) throws {
    guard let url = Bundle.module.url(forResource: sqlFile, withExtension: "sql") else {
        XCTFail("Could not find SQL file named \(sqlFile)", file: file, line: line)
        return
    }
    
    let contents = try String(contentsOf: url)
    
    var state = try ParserState(Lexer(source: contents))
    var lines: [String] = []
    
    while state.current.kind != .eof {
        repeat {
            let output = try parse(&state)
            var emitter = CheckEmitter()
            emitter.emit(output, indent: 0)
            lines.append(contentsOf: emitter.lines)
        } while try state.take(if: .semiColon) && state.current.kind != .eof
    }
    
    if dump {
        for line in lines {
            print(line)
        }
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

fileprivate protocol CheckOptional {
    var innerValue: Any? { get }
}

extension Optional: CheckOptional {
    var innerValue: Any? { self }
}

struct CheckEmitter {
    var lines: [String] = []
    
    mutating func emit(
        _ value: Any,
        for key: String? = nil,
        typeAsBackupKey: Bool = false,
        indent: Int
    ) {
        // Skip optionals
        if let opt = value as? CheckOptional {
            guard let inner = opt.innerValue else { return }
            return emit(inner, for: key, indent: indent)
        }
        
        if isPrimitive(value) {
            write(value, for: key, typeAsBackupKey: typeAsBackupKey, indent: indent)
        } else if value is Range<Substring.Index> {
            return // Skip ranges since it would be too much
        } else if let arr = value as? [Any] {
            guard !arr.isEmpty else { return }
            
            if let key {
                write(key: key, indent: indent)
            }
            
            for value in arr {
                emit(value, indent: indent + 1)
            }
        } else {
            let mirror = Mirror(reflecting: value)
            
            if mirror.displayStyle == .enum && mirror.children.isEmpty {
                // Enum with no payload so just use the value
                if let key {
                    write(value, for: key, typeAsBackupKey: typeAsBackupKey, indent: indent)
                } else {
                    // No key, this is for top level enums. So Foo.bar shows as FOO bar
                    write(value, for: "\(mirror.subjectType)", typeAsBackupKey: typeAsBackupKey, indent: indent)
                }
            } else {
                if mirror.displayStyle != .tuple {
                    // For non tuple types we want a backup name to be the type name.
                    // Tuple types will show as `(foo: Bar)` which is obviously not wanted
                    write(key: key ?? "\(type(of: value))", indent: indent)
                } else if let key {
                    // Write key if there is one.
                    write(key: key, indent: indent)
                }
                
                if mirror.displayStyle == .enum {
                    emitEnum(children: mirror.children, indent: indent)
                } else {
                    emit(
                        children: mirror.children,
                        typeAsBackupKey: mirror.displayStyle == .tuple,
                        indent: indent
                    )
                }
            }
        }
    }
    
    private mutating func emit(children: Mirror.Children, typeAsBackupKey: Bool, indent: Int) {
        for child in children {
            emit(child.value, for: child.label, typeAsBackupKey: typeAsBackupKey, indent: indent + 1)
        }
    }
    
    private mutating func emitEnum(children: Mirror.Children, indent: Int) {
        for child in children {
            if let opt = child.value as? CheckOptional {
                if let inner = opt.innerValue {
                    emit(inner, for: child.label, indent: indent + 1)
                } else {
                    guard let label = child.label else { continue }
                    // If the enum payload is nil we don't want to skip the
                    // the enum, so just write the label
                    write(key: label, indent: indent + 1)
                }
            } else {
                emit(child.value, for: child.label, indent: indent + 1)
            }
        }
    }
    
    private func isPrimitive(_ value: Any) -> Bool {
        return switch value {
        case is Bool, is Int, is Int8, is Int16, is Int32, is Int64,
                is UInt, is UInt8, is UInt16, is UInt32, is UInt64,
                is Float, is Double, is String, is Any.Type, is IdentifierSyntax,
                is LiteralExpr, is TableOptions, is TypeName, is BindParameter,
                is OperatorSyntax: true
        default: false
        }
    }
    
    private mutating func write(
        _ value: Any,
        for key: String? = nil,
        typeAsBackupKey: Bool,
        indent: Int
    ) {
        let indent = String(repeating: " ", count: indent * 2)

        if let key, key.first != "." {
            lines.append("\(indent)\(uppersnakeCase(key)) \(value)")
        } else if typeAsBackupKey, !isPrimitive(value) {
            lines.append("\(indent)\(uppersnakeCase("\(type(of: value))")) \(value)")
        } else {
            lines.append("\(indent)\(value)")
        }
    }
    
    private mutating func write(key: String, indent: Int) {
        guard key.first != "." else { return }
        let key = uppersnakeCase(key)
        let indent = String(repeating: " ", count: indent * 2)
        lines.append("\(indent)\(key)")
    }
    
    /// Note: We upper snakecase the keys. This make it much more obvious
    /// what is a key and what is a value.
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

class TestIt: XCTestCase {
    enum Foo {
        case bar(meow: Int)
        case baz
    }
    func testIt() {
        var emitter = CheckEmitter()
        emitter.emit(Foo.bar(meow: 123), indent: 0)
        
        for line in emitter.lines {
            print(line)
        }
    }
}
