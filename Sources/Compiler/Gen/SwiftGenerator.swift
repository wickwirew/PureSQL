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
    public typealias Migration = SwiftSyntax.ExprSyntax
    
    public struct Query {
        public let statement: Statement
        public let input: GeneratedStruct?
        public let output: GeneratedStruct?
        public let query: DeclSyntax
        
        public var decls: [DeclSyntax] {
            [input?.decl, output?.decl, query].compactMap(\.self)
        }
    }
    
    public struct GeneratedStruct {
        let decl: DeclSyntax
        let name: String
        let fields: [(name: String, type: String)]
    }
    
    public static func migration(
        source: String
    ) throws -> SwiftSyntax.ExprSyntax {
        return """
        \"\"\"
        \(raw: source)
        \"\"\"
        """
    }
    
    public static func table(
        name: Substring,
        columns: Columns
    ) throws -> DeclSyntax {
        return try structDecl(
            name: name,
            fields: columns.map{ ($0.key.description, $0.value) },
            rowDecodable: true
        ).decl
    }
    
    public static func query(
        statement: Statement,
        name: Substring
    ) throws -> Query {
        let parameters = statement.parameters
        
        let (inputTypeName, inputDecl) = try inputType(statement: statement, name: name)
        let (outputTypeName, outputDecl) = try outputType(statement: statement, name: name)
        
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
        
        return Query(
            statement: statement,
            input: inputDecl,
            output: outputDecl,
            query: DeclSyntax(query)
        )
    }
    
    private static func inputType(
        statement: Statement,
        name: Substring
    ) throws -> (String, GeneratedStruct?) {
        guard let firstParam = statement.parameters.first else {
            return ("()", nil)
        }
        
        if statement.parameters.count > 1 {
            let inputTypeName = "\(name.capitalizedFirst)Input"
            
            let inputType = try structDecl(
                name: inputTypeName,
                fields: statement.parameters.map { ($0.name, $0.type) },
                rowDecodable: false
            )
            
            return (inputTypeName, inputType)
        } else {
            // Single input parameter, just use the single value as the parameter type
            return (swiftType(for: firstParam.type), nil)
        }
    }
    
    private static func outputType(
        statement: Statement,
        name: Substring
    ) throws -> (String, GeneratedStruct?) {
        // Make sure there is at least one column else return void
        guard let first = statement.resultColumns
            .columns.values.first else { return ("()", nil) }
        
        // Output can be mapped to a table struct
        if let table = statement.resultColumns.table {
            return (table.capitalizedFirst, nil)
        }
        
        // Only one column returned, just use it's type
        guard statement.resultColumns.columns.count > 1 else {
            return (swiftType(for: first), nil)
        }
        
        let outputTypeName = "\(name.capitalizedFirst)Output"
        
        let outputType = try structDecl(
            name: outputTypeName,
            fields: statement.resultColumns.columns.map{ ($0.key.description, $0.value) },
            rowDecodable: true
        )
        
        return (outputTypeName, outputType)
    }
    
    public static func file(
        migrations: [Migration],
        tables: [Table],
        queries: [Query]
    ) throws -> SourceFileSyntax {
        return try SourceFileSyntax {
            try ImportDeclSyntax("import Foundation")
            try ImportDeclSyntax("import Feather")

            for table in tables {
                table
            }
            
            try EnumDeclSyntax("enum DB") {
                try VariableDeclSyntax("static var migrations: [String]") {
                    ArrayExprSyntax(
                        expressions: migrations.map { SwiftSyntax.ExprSyntax($0) }
                    )
                }
                
                for query in queries {
                    if let input = query.input?.decl {
                        input
                    }
                    
                    if let output = query.output?.decl {
                        output
                    }
                    
                    query.query
                }
            }
            
            for query in queries {
                if let input = query.input {
                    try ExtensionDeclSyntax("extension Query where Input == DB.\(raw: input.name)") {
                        let parameters = input.fields.map { parameter in
                            "\(parameter.name): \(parameter.type)"
                        }.joined(separator: ", ")
                        
                        let args = input.fields.map { parameter in
                            "\(parameter.name): \(parameter.name)"
                        }.joined(separator: ", ")
                        
                        """
                        func execute(\(raw: parameters)) async throws -> Output {
                            try await execute(with: DB.\(raw: input.name)(\(raw: args)))
                        }
                        """
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
        fields unresolvedFields: [(name: String, type: Type)],
        rowDecodable: Bool
    ) throws -> GeneratedStruct {
        var declName = "\(name.capitalizedFirst): Hashable"
        
        var hasId = false
        var fields: [(name: String, type: String)] = []
        for field in unresolvedFields {
            if field.name == "id" {
                hasId = true
            }
            
            fields.append((field.name.description, swiftType(for: field.type)))
        }
        
        if hasId {
            declName.append(", Identifiable")
        }
        
        if rowDecodable {
            declName.append(", RowDecodable")
        }
        
        let decl = try DeclSyntax(StructDeclSyntax(name: "\(raw: declName)") {
            for (column, type) in fields {
                "let \(raw: column): \(raw: type)"
            }
            
            if rowDecodable {
                try InitializerDeclSyntax("init(row: borrowing Feather.Row) throws(FeatherError)") {
                    "var columns = row.columnIterator()"
                    
                    for (name, _) in fields {
                        "self.\(raw: name) = try columns.next()"
                    }
                }
                
                // Only generate the memberwise init if needed
                try InitializerDeclSyntax("init(\(raw: fields.map{ "\($0.name): \($0.type)" }.joined(separator: ", ")))") {
                    for field in fields {
                        "self.\(raw: field.name) = \(raw: field.name)"
                    }
                }
            }
        })
        
        return GeneratedStruct(decl: decl, name: name.description, fields: fields)
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
