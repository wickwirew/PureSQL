//
//  LexerTests.swift
//
//
//  Created by Wes Wickwire on 10/8/24.
//

import Foundation
import XCTest

@testable import Parser

class LexerTests: XCTestCase {
    func testParseKeywordsIsCaseInsensitive() throws {
        let tokens = try tokens(of: "SELECT select Select sElEcT")
        XCTAssertEqual(tokens, [.select, .select, .select, .select, .eof])
    }
    
    func testSymbol() throws {
        let tokens = try tokens(of: "some words select")
        XCTAssertEqual(tokens, [.symbol("some"), .symbol("words"), .select, .eof])
    }
    
    func testString() throws {
        let tokens = try tokens(of: "'some words' 'select'")
        XCTAssertEqual(tokens, [.string("some words"), .string("select"), .eof])
    }
    
    func testNumbers() throws {
        let tokens = try tokens(of: "100 20.2 1_2_3 1_2_3.4 1e2 3.2E-3 0xFF")
        XCTAssertEqual(tokens, [.int(100), .double(20.2), .int(123), .double(123.4), .double(1e2), .double(3.2E-3), .hex(0xFF), .eof])
    }
    
    func testOperators() throws {
        let tokens = try tokens(of: "*/ /* << <= >> >= || -- == != <> -> ->> * . ( ) , + - / % < > & | ^ ~")
        
        XCTAssertEqual(tokens, [
            .starForwardSlash,
            .forwardSlashStar,
            .shiftLeft,
            .lte,
            .shiftRight,
            .gte,
            .concat,
            .dashDash,
            .doubleEqual,
            .notEqual,
            .notEqual2,
            .arrow,
            .doubleArrow,
            .star,
            .dot,
            .openParen,
            .closeParen,
            .comma,
            .plus,
            .minus,
            .divide,
            .modulo,
            .lt,
            .gt,
            .ampersand,
            .pipe,
            .carrot,
            .tilde,
            .eof
        ])
    }
    
    private func tokens(of source: String) throws -> [Token.Kind] {
        var lexer = Lexer(source: source)
        var tokens = [Token.Kind]()
        
        while true {
            let token = try lexer.next()
            tokens.append(token.kind)
            
            if token.kind == .eof {
                break
            }
        }
        
        return tokens
    }
}
