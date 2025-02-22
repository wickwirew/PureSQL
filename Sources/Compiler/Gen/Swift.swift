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
    public typealias Query = [DeclSyntax]
    public typealias Migration = StringLiteralExprSyntax
    
    public static func migration(
        source: String
    ) throws -> StringLiteralExprSyntax {
        StringLiteralExprSyntax(content: source)
    }
    
    public static func query(
        statement: Statement,
        name: Substring
    ) throws -> [DeclSyntax] {
        let parameters = statement.signature.parametersWithNames
        var declarations: [DeclSyntax] = []
        
        let inputTypeName: String
        if let firstParam = statement.signature.parameters.values.first {
            if statement.signature.parameters.count > 1 {
                inputTypeName = "\(name.capitalizedFirst)Input"
                let inputType = DeclSyntax(StructDeclSyntax(name: "\(raw: name.capitalizedFirst)Input") {
                    for input in parameters {
                        "let \(raw: input.name): \(raw: swiftType(for: input.type))"
                    }
                })
                declarations.append(inputType)
            } else {
                // Single input parameter, just use the single value as the parameter type
                inputTypeName = swiftType(for: firstParam.type)
            }
        } else {
            inputTypeName = "()"
        }
        
        let outputTypeName: String
        if statement.signature.noOutput {
            outputTypeName = "()"
        } else {
            // TODO: Check for single output
            outputTypeName = "\(name.capitalizedFirst)Output"
            try declarations.append(outputStructDecl(name: outputTypeName, type: statement.signature.output))
        }
        
        let queryType: String = if statement.signature.noOutput {
            "VoidQuery<\(inputTypeName)>"
        } else {
            switch statement.signature.outputCardinality {
            case .many: "FetchManyQuery<\(inputTypeName), [\(outputTypeName)]>"
            case .single: "FetchSingleQuery<\(inputTypeName), \(outputTypeName)>"
            }
        }
        
        let query = try VariableDeclSyntax("static var \(raw: name): \(raw: queryType)") {
            FunctionCallExprSyntax(
                calledExpression: DeclReferenceExprSyntax(
                    baseName: .identifier(queryType)
                ),
                leftParen: .leftParenToken(),
                arguments: LabeledExprListSyntax {
                    LabeledExprSyntax(
                        label: nil,
                        colon: nil,
                        expression: DeclReferenceExprSyntax(
                            baseName: statement.isReadOnly ? ".read" : ".write"
                        ),
                        trailingComma: nil
                    )
                },
                rightParen: .rightParenToken(),
                trailingClosure: ClosureExprSyntax(
                    signature: ClosureSignatureSyntax(
                        parameterClause: .simpleInput(.init {
                            ClosureShorthandParameterSyntax(name: "input")
                            ClosureShorthandParameterSyntax(name: "transaction")
                        })
                    )
                ) {
                    "let statement = try Feather.Statement(\n\"\"\"\n\(raw: statement.sanitizedSource)\n\"\"\", \ntransaction: transaction\n)"
                    
                    for parameter in parameters {
                        "try statement.bind(value: input.\(raw: parameter.name), to: \(raw: parameter.index))"
                    }
                    
                    "return statement"
                }
            )
        }
        
        declarations.append(DeclSyntax(query))
        
        return declarations
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
                for decl in query {
                    decl
                }
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
        case .alias(_, let alias):
            return alias.description
        }
    }
}
