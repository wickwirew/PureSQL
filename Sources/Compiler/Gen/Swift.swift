//
//  Swift.swift
//  Feather
//
//  Created by Wes Wickwire on 2/16/25.
//

import SwiftSyntax
import SwiftSyntaxBuilder

public struct Swift: Language {
    public typealias File = SourceFileSyntax
    public typealias Query = DeclSyntax
    public typealias Migration = StringLiteralExprSyntax
    
    public static func migration(
        source: String
    ) throws -> StringLiteralExprSyntax {
        StringLiteralExprSyntax(content: source)
    }
    
    public static func query(
        source: String,
        statement: Statement,
        name: Substring
    ) throws -> DeclSyntax {
        let name = name.capitalizedFirst
        let parameters = statement.signature.parametersWithNames
        let querySource = source[statement.rangeWithoutDefinition]

        let queryType: String = if statement.signature.noOutput {
            "VoidQuery"
        } else {
            switch statement.signature.outputCardinality {
            case .many: "FetchManyQuery"
            case .single: "FetchSingleQuery"
            }
        }
        
        return try DeclSyntax(StructDeclSyntax(name: "\(raw: name)Query: \(raw: queryType)") {
            if let firstParam = statement.signature.parameters.values.first {
                if statement.signature.parameters.count > 1 {
                    DeclSyntax(StructDeclSyntax(name: "Input") {
                        for input in parameters {
                            "let \(raw: input.name): \(raw: swiftType(for: input.type))"
                        }
                    })
                } else {
                    // Single input parameter, just use the single value as the parameter type
                    try TypeAliasDeclSyntax("typealias Input = \(raw: swiftType(for: firstParam.type))")
                }
            } else {
                try TypeAliasDeclSyntax("typealias Input = ()")
            }
            
            if statement.signature.noOutput {
                try TypeAliasDeclSyntax("typealias Output = ()")
            } else {
                switch statement.signature.outputCardinality {
                case .single:
                    try outputStructDecl(name: "Output", type: statement.signature.output)
                case .many:
                    try outputStructDecl(name: "Element", type: statement.signature.output)
                    try TypeAliasDeclSyntax("typealias Output = [Element]")
                }
            }
            
            try FunctionDeclSyntax("func statement(\nin transaction: Feather.Transaction,\nwith input: Input\n) throws(FeatherError) -> Feather.Statement") {
                "let statement = try Feather.Statement(\n\"\"\"\n\(raw: querySource)\n\"\"\", \ntransaction: transaction\n)"
                
                for parameter in parameters {
                    "try statement.bind(value: input.\(raw: parameter.name), to: \(raw: parameter.index))"
                }
                
                "return statement"
            }
        })
    }
    
    private static func outputStructDecl(name: String, type: Type?) throws -> DeclSyntax {
        guard case let .row(.named(columns)) = type else {
            fatalError("Output is not a row type")
        }
        
        return try DeclSyntax(StructDeclSyntax(name: "\(raw: name): Feather.RowDecodable") {
            for (column, type) in columns {
                "let \(raw: column): \(raw: swiftType(for: type))"
            }
            
            try InitializerDeclSyntax("init(row: borrowing Feather.Row) throws(FeatherError)") {
                "var columns = row.columnIterator()"
                
                for (column, _) in columns {
                    "self.\(raw: column) = try columns.next()"
                }
            }
        })
    }
    
    public static func file(migrations: [Migration], queries: [Query]) throws -> SourceFileSyntax {
        return try SourceFileSyntax {
            try ImportDeclSyntax("import Feather")
            
            try VariableDeclSyntax("var migrations: [String]") {
                ArrayExprSyntax(
                    expressions: migrations.map { SwiftSyntax.ExprSyntax($0) }
                )
            }
            
            for query in queries {
                query
            }
        }
    }
    
    public static func string(for file: SourceFileSyntax) -> String {
        return file.formatted().description
    }
    
    private static func swiftType(for type: Type) -> String {
        switch type {
        case let .nominal(name):
            return switch name.uppercased() {
            case "REAL": "Double"
            case "INT": "Int"
            case "INTEGER": "Int"
            case "TEXT": "String"
            default: "Any"
            }
        case let .optional(ty):
            return "\(swiftType(for: ty))?"
        case .var, .fn, .row, .error:
            return "Any"
        }
    }
}
