//
//  LexerSliceReleaseTests.swift
//
//
//  Created by Wes Wickwire on 6/27/26.
//

import Testing
@testable import Compiler

/// These tests only failed in a release build.
@Suite
struct LexerSliceReleaseTests {
    @Test func escapedIdentifierStripsDelimiters() {
        #expect(firstIdentifier("\"MyModel.ID\"") == "MyModel.ID")
        #expect(firstIdentifier("[MyModel.ID]") == "MyModel.ID")
        #expect(firstIdentifier("`MyModel.ID`") == "MyModel.ID")
    }

    @Test func stringLiteralStripsQuotes() {
        #expect(firstString("'hello world'") == "hello world")
    }

    @Test func hexLiteral() {
        #expect(firstHex("0xFF") == 255)
    }

    @Test func scientificNotation() {
        #expect(firstDouble("1e3") == 1000)
        #expect(firstDouble("1e-2") == 0.01)
    }

    @Test func aliasedColumnTypeGeneratesUnquotedName() {
        var compiler = Compiler()
        let (_, diags) = compiler.compile(migration: """
        CREATE TABLE myTable (
          id INTEGER AS "MyModel.ID"
        );
        """)
        #expect(diags.isEmpty)
        let table = compiler.schema.tables.values.first!
        let col = table.columns.values.first!
        #expect(!String(describing: col.type).contains("\""))
    }
    
    private func firstIdentifier(_ src: String) -> String? {
        var lexer = Lexer(source: src)
        while true {
            let t = lexer.next()
            if case .eof = t.kind { return nil }
            if case let .identifier(v) = t.kind { return String(v) }
        }
    }

    private func firstString(_ src: String) -> String? {
        var lexer = Lexer(source: src)
        while true {
            let t = lexer.next()
            if case .eof = t.kind { return nil }
            if case let .string(v) = t.kind { return String(v) }
        }
    }

    private func firstHex(_ src: String) -> Int? {
        var lexer = Lexer(source: src)
        while true {
            let t = lexer.next()
            if case .eof = t.kind { return nil }
            if case let .hex(v) = t.kind { return v }
        }
    }

    private func firstDouble(_ src: String) -> Double? {
        var lexer = Lexer(source: src)
        while true {
            let t = lexer.next()
            if case .eof = t.kind { return nil }
            if case let .double(v) = t.kind { return v }
        }
    }
}
