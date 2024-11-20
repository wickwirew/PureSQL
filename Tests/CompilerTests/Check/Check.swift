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
    var output: [P.Output] = []
    
    while state.current.kind != .eof {
        try output.append(parser.parse(state: &state))
    }
    
    let encoder = CheckEncoder(indent: 0)
    let checks = try encoder.encode(output)
    
    try check(
        contents: contents,
        equalTo: checks,
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


fileprivate struct CheckEncoder: Encoder {
    let indent: Int
    var lines = Lines()
    
    class Lines {
        var storage: [String] = []
        
        func write<Value, Key: CodingKey>(_ value: Value, for key: Key, indent: Int) {
            let key = uppersnakeCase(key.stringValue)
            let indent = String(repeating: " ", count: indent * 2)
            storage.append("\(indent)\(key) \(value)")
        }
        
        func write<Value>(_ value: Value, indent: Int) {
            let indent = String(repeating: " ", count: indent * 2)
            storage.append("\(indent)\(value)")
        }
        
        func write<Key: CodingKey>(key: Key, indent: Int) {
            let key = uppersnakeCase(key.stringValue)
            let indent = String(repeating: " ", count: indent * 2)
            storage.append("\(indent)\(key)")
        }
        
        func uppersnakeCase(_ value: String) -> String {
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
    
    var codingPath: [any CodingKey] {
        return []
    }
    
    var userInfo: [CodingUserInfoKey : Any] {
        return [:]
    }
    
    func encode<Value: Encodable>(_ value: Value) throws -> String {
        let encoder = CheckEncoder(indent: 0)
        try value.encode(to: encoder)
        return encoder.lines.storage.joined(separator: "\n")
    }
    
    func container<Key>(keyedBy type: Key.Type) -> KeyedEncodingContainer<Key> where Key : CodingKey {
        let container = Keyed<Key>(encoder: self)
        return KeyedEncodingContainer(container)
    }
    
    func unkeyedContainer() -> any UnkeyedEncodingContainer {
        Unkeyed(encoder: self)
    }
    
    func singleValueContainer() -> any SingleValueEncodingContainer {
        SingleValue(encoder: self)
    }
    
    func write<Value, Key: CodingKey>(_ value: Value, for key: Key) {
        lines.write(value, for: key, indent: indent)
    }
    
    func write<Value>(_ value: Value) {
        lines.write(value, indent: indent)
    }
    
    func write<Key: CodingKey>(key: Key) {
        lines.write(key: key, indent: indent)
    }
    
    func indented() -> CheckEncoder {
        return CheckEncoder(indent: indent + 1, lines: lines)
    }
}

extension CheckEncoder {
    struct Keyed<Key: CodingKey>: KeyedEncodingContainerProtocol {
        let encoder: CheckEncoder
        var codingPath: [any CodingKey] { [] }
        
        func superEncoder() -> any Encoder {
            return encoder
        }
        
        func encodeNil(forKey key: Key) throws {}
        
        func nestedContainer<NestedKey>(
            keyedBy keyType: NestedKey.Type,
            forKey key: Key
        ) -> KeyedEncodingContainer<NestedKey> where NestedKey : CodingKey {
            let container = Keyed<NestedKey>(encoder: encoder.indented())
            return KeyedEncodingContainer(container)
        }
        
        func nestedUnkeyedContainer(forKey key: Key) -> any UnkeyedEncodingContainer {
            return Unkeyed(encoder: encoder.indented())
        }
        
        func superEncoder(forKey key: Key) -> any Encoder {
            return encoder
        }
        
        func encode<T>(_ value: T, forKey key: Key) throws where T : Encodable {
            encoder.write(key: key)
            try value.encode(to: encoder.indented())
        }
        
        func encode(_ value: Bool, forKey key: Key) throws { encoder.write(value, for: key) }
        func encode(_ value: Int, forKey key: Key) throws { encoder.write(value, for: key) }
        func encode(_ value: Int8, forKey key: Key) throws { encoder.write(value, for: key) }
        func encode(_ value: Int16, forKey key: Key) throws { encoder.write(value, for: key) }
        func encode(_ value: Int32, forKey key: Key) throws { encoder.write(value, for: key) }
        func encode(_ value: Int64, forKey key: Key) throws { encoder.write(value, for: key) }
        func encode(_ value: UInt, forKey key: Key) throws { encoder.write(value, for: key) }
        func encode(_ value: UInt8, forKey key: Key) throws { encoder.write(value, for: key) }
        func encode(_ value: UInt16, forKey key: Key) throws { encoder.write(value, for: key) }
        func encode(_ value: UInt32, forKey key: Key) throws { encoder.write(value, for: key) }
        func encode(_ value: UInt64, forKey key: Key) throws { encoder.write(value, for: key) }
        func encode(_ value: Float, forKey key: Key) throws { encoder.write(value, for: key) }
        func encode(_ value: Double, forKey key: Key) throws { encoder.write(value, for: key) }
        func encode(_ value: String, forKey key: Key) throws { encoder.write(value, for: key) }
        
        func encodeIfPresent(_ value: Bool?, forKey key: Key) throws {
            guard let value else { return }
            encoder.write(value, for: key)
        }
        
        func encodeIfPresent(_ value: Int?, forKey key: Key) throws {
            guard let value else { return }
            encoder.write(value, for: key)
        }
        
        func encodeIfPresent(_ value: Int8?, forKey key: Key) throws {
            guard let value else { return }
            encoder.write(value, for: key)
        }
        
        func encodeIfPresent(_ value: Int16?, forKey key: Key) throws {
            guard let value else { return }
            encoder.write(value, for: key)
        }
        
        func encodeIfPresent(_ value: Int32?, forKey key: Key) throws {
            guard let value else { return }
            encoder.write(value, for: key)
        }
        
        func encodeIfPresent(_ value: Int64?, forKey key: Key) throws {
            guard let value else { return }
            encoder.write(value, for: key)
        }
        
        func encodeIfPresent(_ value: UInt?, forKey key: Key) throws {
            guard let value else { return }
            encoder.write(value, for: key)
        }
        
        func encodeIfPresent(_ value: UInt8?, forKey key: Key) throws {
            guard let value else { return }
            encoder.write(value, for: key)
        }
        
        func encodeIfPresent(_ value: UInt16?, forKey key: Key) throws {
            guard let value else { return }
            encoder.write(value, for: key)
        }
        
        func encodeIfPresent(_ value: UInt32?, forKey key: Key) throws {
            guard let value else { return }
            encoder.write(value, for: key)
        }
        
        func encodeIfPresent(_ value: UInt64?, forKey key: Key) throws {
            guard let value else { return }
            encoder.write(value, for: key)
        }
        
        func encodeIfPresent(_ value: Float?, forKey key: Key) throws {
            guard let value else { return }
            encoder.write(value, for: key)
        }
        
        func encodeIfPresent(_ value: Double?, forKey key: Key) throws {
            guard let value else { return }
            encoder.write(value, for: key)
        }
        
        func encodeIfPresent(_ value: String?, forKey key: Key) throws {
            guard let value else { return }
            encoder.write(value, for: key)
        }
    }

}

extension CheckEncoder {
    struct SingleValue: SingleValueEncodingContainer {
        let encoder: CheckEncoder
        var codingPath: [any CodingKey] { [] }
        
        func encodeNil() throws {}
        func encode(_ value: Bool) throws { encoder.write(value) }
        func encode(_ value: Int) throws { encoder.write(value) }
        func encode(_ value: Int8) throws { encoder.write(value) }
        func encode(_ value: Int16) throws { encoder.write(value) }
        func encode(_ value: Int32) throws { encoder.write(value) }
        func encode(_ value: Int64) throws { encoder.write(value) }
        func encode(_ value: UInt) throws { encoder.write(value) }
        func encode(_ value: UInt8) throws { encoder.write(value) }
        func encode(_ value: UInt16) throws { encoder.write(value) }
        func encode(_ value: UInt32) throws { encoder.write(value) }
        func encode(_ value: UInt64) throws { encoder.write(value) }
        func encode(_ value: Float) throws { encoder.write(value) }
        func encode(_ value: Double) throws { encoder.write(value) }
        func encode(_ value: String) throws { encoder.write(value) }
        
        func encode<T>(_ value: T) throws where T: Encodable {
            try value.encode(to: encoder.indented())
        }
    }
}

extension CheckEncoder {
    struct Unkeyed: UnkeyedEncodingContainer {
        var count: Int = 0
        let encoder: CheckEncoder
        var codingPath: [any CodingKey] { [] }
        
        func encodeNil() throws {}
        func encode(_ value: Bool) throws { encoder.write(value) }
        func encode(_ value: Int) throws { encoder.write(value) }
        func encode(_ value: Int8) throws { encoder.write(value) }
        func encode(_ value: Int16) throws { encoder.write(value) }
        func encode(_ value: Int32) throws { encoder.write(value) }
        func encode(_ value: Int64) throws { encoder.write(value) }
        func encode(_ value: UInt) throws { encoder.write(value) }
        func encode(_ value: UInt8) throws { encoder.write(value) }
        func encode(_ value: UInt16) throws { encoder.write(value) }
        func encode(_ value: UInt32) throws { encoder.write(value) }
        func encode(_ value: UInt64) throws { encoder.write(value) }
        func encode(_ value: Float) throws { encoder.write(value) }
        func encode(_ value: Double) throws { encoder.write(value) }
        func encode(_ value: String) throws { encoder.write(value) }
        
        func encode<T>(_ value: T) throws where T: Encodable {
            try value.encode(to: encoder)
        }
        
        mutating func nestedContainer<NestedKey>(
            keyedBy keyType: NestedKey.Type
        ) -> KeyedEncodingContainer<NestedKey> where NestedKey : CodingKey {
            let container = Keyed<NestedKey>(encoder: encoder.indented())
            return KeyedEncodingContainer(container)
        }
        
        mutating func nestedUnkeyedContainer() -> any UnkeyedEncodingContainer {
            return Unkeyed(encoder: encoder.indented())
        }
        
        mutating func superEncoder() -> any Encoder {
            return encoder
        }
    }
}


class CheckLines {
    
    
    
}

struct CheckEmitter {
    var storage: [String] = []
    
    mutating func emit(_ value: Any, for key: String? = nil, indent: Int) {
        if isPrimitive(value) {
            write(value, for: key, indent: indent)
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
            storage.append("\(indent)\(uppersnakeCase(key)) \(value)")
        } else {
            storage.append("\(indent)\(value)")
        }
    }
    
    private mutating func write(key: String, indent: Int) {
        let key = uppersnakeCase(key)
        let indent = String(repeating: " ", count: indent * 2)
        storage.append("\(indent)\(key)")
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

class TestIt: XCTestCase {
    struct Foo {
        let bar = 1
        let baz = "MEowwer"
        let qux = Qux()
        let nums = [1,2,3]
    }
    
    struct Qux {
        let meow = "Meow"
        let anal = 1
        let nums = [1,2,3]
    }
    
    func testIt() {
        var emitter = CheckEmitter()
        emitter.emit(Foo(), indent: 0)
        
        for line in emitter.storage {
            print(line)
        }
    }
}
