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
    
    func testOperators() throws {
        let tokens = try tokens(of: "*/ /* << <= >> >= || -- == != <> -> ->> * . ( ) , + - / % < > & | ^ ~ '")
        
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
            .notEqual,
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
            .bitwiseAnd,
            .bitwiseOr,
            .bitwiseXor,
            .tilde,
            .singleQuote,
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
