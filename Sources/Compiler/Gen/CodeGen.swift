//
//  CodeGen.swift
//  Feather
//
//  Created by Wes Wickwire on 2/15/25.
//

import Foundation
import SwiftSyntax
import SwiftSyntaxBuilder

public struct CodeGen {
    public let schema: Schema
    public let statements: [Statement]
    public let source: String
    public let addImports: Bool
    
    public init(
        schema: Schema,
        statements: [Statement],
        source: String,
        addImports: Bool = true
    ) {
        self.schema = schema
        self.statements = statements
        self.source = source
        self.addImports = addImports
    }
    
    public mutating func gen() throws -> SourceFileSyntax {
        return try SourceFileSyntax {
            if addImports {
                try ImportDeclSyntax("import Feather")
            }
            
            for statement in statements.filter({ !$0.signature.isEmpty }) {
                if let name = statement.name {
                    try gen(name: name, statement: statement)
                }
            }
        }
    }
    
    private mutating func gen(
        name: Substring,
        statement: Statement
    ) throws -> DeclSyntax {
        let name = name.capitalizedFirst
        let parameters = statement.signature.parametersWithNames
        let querySource = source[statement.rangeWithoutDefinition]
        let hasInput = !parameters.isEmpty
        
        return try DeclSyntax(StructDeclSyntax(name: "\(raw: name)Query: DatabaseQuery") {
            if statement.signature.output != nil {
                if statement.signature.outputIsSingleElement {
                    try TypeAliasDeclSyntax("typealias Output = \(raw: name)")
                } else {
                    try TypeAliasDeclSyntax("typealias Output = [\(raw: name)]")
                }
            } else {
                try TypeAliasDeclSyntax("typealias Output = ()")
            }
            
            try TypeAliasDeclSyntax("typealias Context = Connection")
            
            if !hasInput {
                try TypeAliasDeclSyntax("typealias Input = ()")
            }
            
            try FunctionDeclSyntax("func statement(\nin connection: borrowing Connection,\nwith input: Input\n) throws(FeatherError) -> Statement") {
                "\(raw: hasInput ? "var" : "let") statement = try Statement(\"\"\"\n\(raw: querySource)\n\"\"\", \nconnection: connection\n)"
                
                for parameter in parameters {
                    "try statement.bind(value: input.\(raw: parameter.name), to: \(raw: parameter.index))"
                }
                
                "return statement"
            }
            
            if hasInput {
                DeclSyntax(StructDeclSyntax(name: "Input") {
                    for input in parameters {
                        "let \(raw: input.name): \(raw: swiftType(for: input.type))"
                    }
                })
            }
            
            if case let .row(.named(columns)) = statement.signature.output {
                try DeclSyntax(StructDeclSyntax(name: "\(raw: name): RowDecodable") {
                    for (column, type) in columns {
                        "let \(raw: column): \(raw: swiftType(for: type))"
                    }
                    
                    try InitializerDeclSyntax("init(cursor: borrowing Cursor) throws(FeatherError)") {
                        "var columns = cursor.indexedColumns()"
                        
                        for (column, _) in columns {
                            "self.\(raw: column) = try columns.next()"
                        }
                    }
                })
            }
        })
    }
    
    private func swiftType(for type: Type) -> String {
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
