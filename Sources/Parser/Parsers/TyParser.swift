//
//  TyParser.swift
//
//
//  Created by Wes Wickwire on 10/9/24.
//

import Schema

/// Parses out a type. This will convert the type name to a concrete
/// known type that will be easier to use later in the process.
///
/// https://www.sqlite.org/syntax/type-name.html
struct TyParser: Parser {
    static let continuations: Set<Token.Kind> = [
        .symbol("BIG"),
        .symbol("INT"),
        .symbol("PRECISION"),
        .symbol("CHARACTER"),
    ]
    
    func parse(state: inout ParserState) throws -> Ty {
        let range = state.range
        let name = try SymbolParser()
            .collect(if: TyParser.continuations)
            .parse(state: &state)
            .joined(separator: " ")
        
        if state.is(of: .openParen) {
            let args = try SignedNumberParser()
                .commaSeparated()
                .inParenthesis()
                .parse(state: &state)
            
            guard args.count < 3 else {
                throw ParsingError.inCorrectNumberOfArgs(at: range)
            }
            
            let first = args.first
            let second = args.count > 1 ? args[1] : nil
            return try tyOrThrow(at: range, name: name, with: first, and: second)
        } else {
            return try tyOrThrow(at: range, name: name)
        }
    }
    
    private func tyOrThrow(
        at range: Range<String.Index>,
        name: String,
        with first: Numeric? = nil,
        and second: Numeric? = nil
    ) throws -> Ty {
        switch name.uppercased() {
        case "INT": return .int
        case "INTEGER": return .integer
        case "TINYINT": return .tinyint
        case "SMALLINT": return .smallint
        case "MEDIUMINT": return .mediumint
        case "BIGINT": return .bigint
        case "UNSIGNED BIG INT": return .unsignedBigInt
        case "INT2": return .int2
        case "INT8": return .int8
        case "NUMERIC": return .numeric
        case "DECIMAL":
            guard let first, let second else {
                throw ParsingError.inCorrectNumberOfArgs(at: range)
            }
            return .decimal(Int(first), Int(second))
        case "BOOLEAN": return .boolean
        case "DATE": return .date
        case "DATETIME": return .datetime
        case "REAL": return .real
        case "DOUBLE": return .double
        case "DOUBLE PRECISION": return .doublePrecision
        case "FLOAT": return .float
        case "CHARACTER": 
            guard let first, second == nil else {
                throw ParsingError.inCorrectNumberOfArgs(at: range)
            }
            return .character(Int(first))
        case "VARCHAR":
            guard let first, second == nil else {
                throw ParsingError.inCorrectNumberOfArgs(at: range)
            }
            return .varchar(Int(first))
        case "VARYING CHARACTER":
            guard let first, second == nil else {
                throw ParsingError.inCorrectNumberOfArgs(at: range)
            }
            return .varyingCharacter(Int(first))
        case "NCHAR":
            guard let first, second == nil else {
                throw ParsingError.inCorrectNumberOfArgs(at: range)
            }
            return .nchar(Int(first))
        case "NATIVE CHARACTER":
            guard let first, second == nil else {
                throw ParsingError.inCorrectNumberOfArgs(at: range)
            }
            return .nativeCharacter(Int(first))
        case "NVARCHAR":
            guard let first, second == nil else {
                throw ParsingError.inCorrectNumberOfArgs(at: range)
            }
            return .nvarchar(Int(first))
        case "TEXT": return .text
        case "CLOB": return .clob
        case "BLOB": return .blob
        default: throw ParsingError(description: "Invalid type name '\(name)'", sourceRange: range)
        }
    }
    
}
