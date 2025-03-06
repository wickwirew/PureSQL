//
//  SwiftGenerator.swift
//  Feather
//
//  Created by Wes Wickwire on 2/16/25.
//

import SwiftSyntax
import SwiftSyntaxBuilder

public struct SwiftGenerator: Language {
    public typealias Table = DeclSyntax
    public typealias File = SourceFileSyntax
    public typealias Query = [DeclSyntax]
    public typealias Migration = StringLiteralExprSyntax
    
    public static func migration(
        source: String
    ) throws -> StringLiteralExprSyntax {
        StringLiteralExprSyntax(content: source)
    }
    
    public static func table(
        name: Substring,
        columns: Columns
    ) throws -> DeclSyntax {
        return try structDecl(
            name: name,
            columns: columns,
            rowDecodable: true
        )
    }
    
    public static func query(
        statement: Statement,
        name: Substring
    ) throws -> [DeclSyntax] {
        let parameters = Array(statement.parameters.values.sorted(by: { $0.index < $1.index }))
        var declarations: [DeclSyntax] = []
        
        let inputTypeName = inputType(statement: statement, name: name, declarations: &declarations)
        let outputTypeName = try outputType(statement: statement, name: name, declarations: &declarations)
        
        let queryType: String = if statement.noOutput {
            "VoidQuery<\(inputTypeName)>"
        } else {
            switch statement.outputCardinality {
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
                    let source = statement.sourceSegments.map { segment in
                        switch segment {
                        case .text(let text):
                            return text.description
                        case .rowParam(let param):
                            return questionMarks(for: parameters.count > 1 ? param.name : "input")
                        }
                    }.joined()
                    
                    let hasParams = !parameters.isEmpty
                    
                    "\(raw: hasParams ? "var" : "let") statement = try Feather.Statement(\n\"\"\"\n\(raw: source)\n\"\"\", \ntransaction: transaction\n)"
                    
                    if let first = parameters.first, parameters.count == 1 {
                        bind(param: first, isField: false)
                    } else {
                        for parameter in parameters {
                            bind(param: parameter, isField: true)
                        }
                    }
                    
                    "return statement"
                }
            )
        }
        
        declarations.append(DeclSyntax(query))
        
        return declarations
    }
    
    private static func inputType(
        statement: Statement,
        name: Substring,
        declarations: inout [DeclSyntax]
    ) -> String {
        guard let firstParam = statement.parameters.values.first else {
            return "()"
        }
        
        if statement.parameters.count > 1 {
            let inputTypeName = "\(name.capitalizedFirst)Input"
            let inputType = DeclSyntax(StructDeclSyntax(name: "\(raw: inputTypeName)") {
                for input in statement.parameters.values {
                    "let \(raw: input.name): \(raw: swiftType(for: input.type))"
                }
            })
            declarations.append(inputType)
            return inputTypeName
        } else {
            // Single input parameter, just use the single value as the parameter type
            return swiftType(for: firstParam.type)
        }
    }
    
    private static func outputType(
        statement: Statement,
        name: Substring,
        declarations: inout [DeclSyntax]
    ) throws -> String {
        // Make sure there is at least one column else return void
        guard let first = statement.resultColumns
            .columns.values.first else { return "()" }
        
        // Output can be mapped to a table struct
        if let table = statement.resultColumns.table {
            return table.capitalizedFirst
        }
        
        // Only one column returned, just use it's type
        guard statement.resultColumns.columns.count > 1 else {
            return swiftType(for: first)
        }
        
        let outputTypeName = "\(name.capitalizedFirst)Output"
        
        let outputType = try structDecl(
            name: outputTypeName,
            columns: statement.resultColumns.columns,
            rowDecodable: true
        )
        
        declarations.append(outputType)
        return outputTypeName
    }
    
    public static func file(
        migrations: [Migration],
        tables: [Table],
        queries: [Query]
    ) throws -> SourceFileSyntax {
        return try SourceFileSyntax {
            try ImportDeclSyntax("import Feather")
            
            for table in tables {
                table
            }
            
            try EnumDeclSyntax("enum Queries") {
                try VariableDeclSyntax("static var migrations: [String]") {
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
    }
    
    public static func string(for file: SourceFileSyntax) -> String {
        return file.formatted().description
    }
    
    public static func structDecl<Name: StringProtocol>(
        name: Name,
        columns: Columns,
        rowDecodable: Bool
    ) throws -> DeclSyntax {
        var declName = "\(name.capitalizedFirst): Hashable"
        
        if columns["id"] != nil {
            declName.append(", Identifiable")
        }
        
        if rowDecodable {
            declName.append(", RowDecodable")
        }
        
        return try DeclSyntax(StructDeclSyntax(name: "\(raw: declName)") {
            for (column, type) in columns {
                "let \(raw: column): \(raw: swiftType(for: type))"
            }
            
            if rowDecodable {
                try InitializerDeclSyntax("init(row: borrowing Feather.Row) throws(FeatherError)") {
                    "var columns = row.columnIterator()"
                    
                    for (column, _) in columns {
                        "self.\(raw: column) = try columns.next()"
                    }
                }
            }
        })
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
        case let .row(.unknown(ty)):
            return "[\(swiftType(for: ty))]"
        case .var, .fn, .row, .error:
            return "Any"
        case .alias(_, let alias):
            return alias.description
        }
    }
    
    @CodeBlockItemListBuilder
    private static func bind(
        param: Parameter<String>,
        isField: Bool
    ) -> CodeBlockItemListSyntax {
        let paramName = isField ? "input.\(param.name)" : "input"
        
        switch param.type {
        case .row:
            """
            for element in \(raw: paramName) {
                try statement.bind(value: element)
            }
            """
        default:
            "try statement.bind(value: \(raw: paramName))"
        }
    }
    
    private static func questionMarks(for param: String) -> String {
        return "(\(interpolated("\(param).sqlQuestionMarks")))"
    }
    
    private static func interpolated(_ value: String) -> String {
        return  "\\(\(value))"
    }
}
