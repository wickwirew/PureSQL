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
        public let inputStruct: GeneratedStruct?
        public let inputTypeName: String
        public let outputStruct: GeneratedStruct?
        public let outputTypeName: String
        public let query: DeclSyntax
        
        public var decls: [DeclSyntax] {
            [inputStruct?.decl, outputStruct?.decl, query].compactMap(\.self)
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
        
        let inputDecl = try generateInputTypeIfNeeded(statement: statement, name: name)
        let outputDecl = try generateOutputTypeIfNeeded(statement: statement, name: name)
        
        let inputTypeName = inputType(statement: statement, generatedInputType: inputDecl)
        let outputTypeName = outputType(statement: statement, generatedOutputType: outputDecl)
        
        let queryType: String = if statement.noOutput {
            "VoidQuery<\(inputTypeName)>"
        } else {
            switch statement.outputCardinality {
            case .many: "FetchManyQuery<\(inputTypeName), \(outputTypeName)>"
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
            inputStruct: inputDecl,
            inputTypeName: inputTypeName,
            outputStruct: outputDecl,
            outputTypeName: outputTypeName,
            query: DeclSyntax(query)
        )
    }
    
    private static func generateInputTypeIfNeeded(
        statement: Statement,
        name: Substring
    ) throws -> GeneratedStruct? {
        guard statement.parameters.count > 1 else { return nil }
        
        let inputTypeName = "\(name.capitalizedFirst)Input"
        
        let inputType = try structDecl(
            name: inputTypeName,
            fields: statement.parameters.map { ($0.name, $0.type) },
            rowDecodable: false
        )
        
        return inputType
    }
    
    private static func inputType(
        statement: Statement,
        generatedInputType: GeneratedStruct?
    ) -> String {
        guard let firstParam = statement.parameters.first else {
            return "()"
        }
        
        return generatedInputType?.name ?? swiftType(for: firstParam.type)
    }
    
    private static func outputType(
        statement: Statement,
        generatedOutputType: GeneratedStruct?
    ) -> String {
        guard !statement.noOutput,
              let firstColumn = statement.resultColumns.columns.values.first else {
            return "()"
        }
        
        // Returns the entire columns of a table, so we can just return the table
        if let table = statement.resultColumns.table {
            return table.capitalizedFirst
        }
        
        let type = generatedOutputType?.name ?? swiftType(for: firstColumn.root)
        
        return switch statement.outputCardinality {
        case .single: type
        case .many: "[\(type)]"
        }
    }
    
    private static func generateOutputTypeIfNeeded(
        statement: Statement,
        name: Substring
    ) throws -> GeneratedStruct? {
        // Make sure there is at least one column else return void
        guard !statement.resultColumns.columns.isEmpty  else { return nil }
        
        // Output can be mapped to a table struct
        guard statement.resultColumns.table == nil else { return nil }
        
        // Only one column returned, just use it's type
        guard statement.resultColumns.columns.count > 1 else { return nil }
        
        let outputTypeName = "\(name.capitalizedFirst)Output"
        
        return try structDecl(
            name: outputTypeName,
            fields: statement.resultColumns.columns.map{ ($0.key.description, $0.value) },
            rowDecodable: true
        )
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
                    if let input = query.inputStruct?.decl {
                        input
                    }
                    
                    if let output = query.outputStruct?.decl {
                        output
                    }
                    
                    query.query
                }
            }
            
            for query in queries {
                if let name = query.statement.name?.capitalizedFirst {
                    try TypeAliasDeclSyntax("typealias \(raw: name)Query = any Query<\(raw: query.inputTypeName), \(raw: query.outputTypeName)>")
                }
                
                if let input = query.inputStruct {
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
