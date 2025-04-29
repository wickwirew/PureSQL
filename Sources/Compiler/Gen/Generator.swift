//
//  Generator.swift
//  Feather
//
//  Created by Wes Wickwire on 4/28/25.
//

import OrderedCollections
import SwiftSyntax
import SwiftSyntaxBuilder

public protocol Language2 {
    /// Returns the Language builtin for the given SQL type
    static func builtinType(for type: Type) -> String
    
    /// The query type name with the given cardinality, input and output
    static func queryType(
        for cardinality: Cardinality?,
        input: BuiltinOrGenerated?,
        output: BuiltinOrGenerated?
    ) -> String
    
    /// A file source code containing all of the generated tables, queries and migrations.
    static func file(
        migrations: [String],
        tables: [GeneratedModel],
        queries: [GeneratedQuery],
        options: GenerationOptions
    ) throws -> String
    
    /// Function to generate a interpolation segment in a string
    /// that contains the code to generate question marks for a
    /// parameter with the given name.
    ///
    /// Example:
    /// ```swift
    /// \(input.sqlQuestionMarks)
    /// ```
    static func interpolatedQuestionMarks(for param: String) -> String
}

extension Language2 {
    public static func generate(
        migrations: [String],
        queries: [Statement],
        schema: Schema,
        options: GenerationOptions
    ) throws -> String {
        let tables = schema.mapValues(model(for:))
        let queries = queries.map { query(for: $0, tables: tables) }
        
        return try file(
            migrations: migrations,
            tables: Array(tables.values),
            queries: queries,
            options: options
        )
    }
    
    private static func query(
        for statement: Statement,
        tables: OrderedDictionary<Substring, GeneratedModel>
    ) -> GeneratedQuery {
        guard let name = statement.name else {
            fatalError("Upstream error should have caught this")
        }
        
        let input = inputTypeIfNeeded(statement: statement, name: name)
        let output = outputTypeIfNeeded(statement: statement, name: name, tables: tables)
        
        let type = queryType(
            for: statement.noOutput ? nil : statement.outputCardinality,
            input: input,
            output: output
        )
        
        // Join the source segments together inserting the code to assemble the
        // question marks for any input.
        let sql = statement.sourceSegments.map { segment in
            switch segment {
            case .text(let text):
                return text.description
            case .rowParam(let param):
                return interpolatedQuestionMarks(
                    for: statement.parameters.count > 1 ? param.name : "input"
                )
            }
        }.joined()
        
        return GeneratedQuery(
            name: name.description,
            type: type,
            input: input,
            output: output,
            sourceSql: sql,
            isReadOnly: statement.isReadOnly
        )
    }
    
    private static func model(for table: Table) -> GeneratedModel {
        GeneratedModel(
            name: table.name.capitalizedFirst,
            fields: table.columns.reduce(into: [:]) { fields, column in
                let name = column.key.description
                let type = column.value
                fields[name] = GeneratedField(
                    name: name,
                    type: builtinType(for: type),
                    isArray: type.isRow
                )
            },
            isTable: true
        )
    }
    
    private static func inputTypeIfNeeded(
        statement: Statement,
        name: Substring
    ) -> BuiltinOrGenerated? {
        guard let firstParameter = statement.parameters.first else { return nil }
        
        guard statement.parameters.count > 1 else {
            return .builtin(
                builtinType(for: firstParameter.type),
                isArray: firstParameter.type.isRow
            )
        }
        
        let inputTypeName = "\(name.capitalizedFirst)Input"
        
        let model = GeneratedModel(
            name: inputTypeName,
            fields: statement.parameters.reduce(into: [:]) { fields, parameter in
                fields[parameter.name] = GeneratedField(
                    name: parameter.name,
                    type: builtinType(for: parameter.type),
                    isArray: parameter.type.isRow
                )
            },
            isTable: false
        )
        
        return .model(model)
    }
    
    private static func outputTypeIfNeeded(
        statement: Statement,
        name: Substring,
        tables: OrderedDictionary<Substring, GeneratedModel>
    ) -> BuiltinOrGenerated? {
        // Output can be mapped to a table struct
        if let tableName = statement.resultColumns.table, let table = tables[tableName] {
            return .model(table)
        }
        
        // Make sure there is at least one column else return void
        guard let firstColumn = statement.resultColumns.columns.values.first else {
            return nil
        }
        
        // Only one column returned, just use it's type
        guard statement.resultColumns.columns.count > 1 else {
            return .builtin(builtinType(for: firstColumn), isArray: firstColumn.isRow)
        }
        
        let outputTypeName = "\(name.capitalizedFirst)Output"
        
        let model = GeneratedModel(
            name: outputTypeName,
            fields: statement.resultColumns.columns.reduce(into: [:]) { fields, parameter in
                let name = parameter.key.description
                let type = parameter.value
                fields[name] = GeneratedField(
                    name: name,
                    type: builtinType(for: type),
                    isArray: type.isRow
                )
            },
            isTable: false
        )
        
        return .model(model)
    }
}

public struct SwiftLanguage: Language2 {
    public static func interpolatedQuestionMarks(for param: String) -> String {
        return  "\\(\(param).sqlQuestionMarks)"
    }
    
    public static func builtinType(for type: Type) -> String {
        return switch type {
        case let .nominal(name):
            switch name.uppercased() {
            case "REAL": "Double"
            case "INT": "Int"
            case "INTEGER": "Int"
            case "TEXT": "String"
            default: "Any"
            }
        case let .optional(ty): "\(builtinType(for: ty))?"
        case let .row(.unknown(ty)): "[\(builtinType(for: ty))]"
        case .var, .fn, .row, .error: "Any"
        case .alias(_, let alias): alias.description
        }
    }
    
    public static func file(
        migrations: [String],
        tables: [GeneratedModel],
        queries: [GeneratedQuery],
        options: GenerationOptions
    ) throws -> String {
        let file = try SourceFileSyntax {
            try ImportDeclSyntax("import Foundation")
            try ImportDeclSyntax("import Feather")

            for table in tables {
                try declaration(for: table, isOutput: true, options: options)
            }
            
            try EnumDeclSyntax("enum DB") {
                try declaration(for: migrations, options: options)
                
                for query in queries {
                    if case let .model(input) = query.input, !input.isTable {
                        try declaration(for: input, isOutput: false, options: options)
                    }
                    
                    if case let .model(output) = query.output, !output.isTable {
                        try declaration(for: output, isOutput: true, options: options)
                    }
                    
                    try declaration(for: query, options: options)
                }
            }
            
            for query in queries {
                try typealiasFor(query: query)
                
                if case let .model(input) = query.input {
                    try extensionForInput(query: query, input: input)
                }
            }
        }
        
        return file.formatted().description
    }
    
    public static func queryType(
        for cardinality: Cardinality?,
        input: BuiltinOrGenerated?,
        output: BuiltinOrGenerated?
    ) -> String {
        let input = input?.description ?? "()"
        let output = output?.description ?? "()"
        
        return switch cardinality {
        case .single: "FetchSingleQuery<\(input), \(output)>"
        case .many: "FetchManyQuery<\(input), \(output)>"
        default: "VoidQuery<\(input)>"
        }
    }
    
    private static func declaration(
        for migrations: [String],
        options: GenerationOptions
    ) throws -> DeclSyntax {
        let variable = try VariableDeclSyntax("static var migrations: [String]") {
            ArrayExprSyntax(
                expressions: migrations.map { source in
                    SwiftSyntax.ExprSyntax(stringLiteral(of: source, multiline: true)
                        .with(\.trailingTrivia, .newline))
                }
            )
        }
        
        return DeclSyntax(variable)
    }
    
    private static func declaration(
        for query: GeneratedQuery,
        options: GenerationOptions
    ) throws -> DeclSyntax {
        let query = try VariableDeclSyntax("static var \(raw: query.name): \(raw: query.type)") {
            FunctionCallExprSyntax(
                calledExpression: DeclReferenceExprSyntax(
                    baseName: .identifier(query.type)
                ),
                leftParen: .leftParenToken(),
                arguments: LabeledExprListSyntax {
                    LabeledExprSyntax(
                        label: nil,
                        colon: nil,
                        expression: DeclReferenceExprSyntax(
                            baseName: query.isReadOnly ? ".read" : ".write"
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
                    let sql = stringLiteral(of: query.sourceSql, multiline: true)
                    let statementBinding: TokenSyntax = .keyword(query.input == nil ? .let : .var)
                    "\(statementBinding) statement = try Feather.Statement(\(sql), \ntransaction: transaction\n)"

                    if let input = query.input {
                        switch input {
                        case let .builtin(_, isArray):
                            bind(field: nil, isArray: isArray)
                        case .model(let model):
                            for field in model.fields.values {
                                bind(field: field.name, isArray: field.isArray)
                            }
                        }
                    }

                    "return statement"
                }
            )
        }
        
        return DeclSyntax(query)
    }
    
    private static func declaration(
        for model: GeneratedModel,
        isOutput: Bool,
        options: GenerationOptions
    ) throws -> DeclSyntax {
        let inheretance = InheritanceClauseSyntax {
            InheritedTypeSyntax(type: TypeSyntax("Hashable"))
            
            if model.fields["id"] != nil {
                InheritedTypeSyntax(type: TypeSyntax("Identifiable"))
            }
            
            if isOutput {
                InheritedTypeSyntax(type: TypeSyntax("RowDecodable"))
            }
        }
        
        let strct = StructDeclSyntax(
            name: TokenSyntax.identifier(model.name),
            inheritanceClause: inheretance
        ) {
            for field in model.fields.values {
                variableDecl(name: field.name, type: field.type)
            }
            
            if isOutput {
                rowDecodableInit(for: model)
                memberwiseInit(for: model)
            }
        }
        
        return DeclSyntax(strct)
    }
    
    private static func rowDecodableInit(
        for model: GeneratedModel
    ) -> InitializerDeclSyntax {
        return InitializerDeclSyntax(
            signature: FunctionSignatureSyntax(
                parameterClause: FunctionParameterClauseSyntax(
                    parameters: [
                        FunctionParameterSyntax(
                            firstName: "row",
                            type: IdentifierTypeSyntax(name: "borrowing Feather.Row")
                        )
                    ]
                ),
                effectSpecifiers: FunctionEffectSpecifiersSyntax(
                    throwsClause: ThrowsClauseSyntax(
                        throwsSpecifier: TokenSyntax.keyword(.throws),
                        leftParen: TokenSyntax.leftParenToken(),
                        type: TypeSyntax("FeatherError"),
                        rightParen: TokenSyntax.rightParenToken()
                    )
                )
            )
        ) {
            "var columns = row.columnIterator()"
            
            for field in model.fields.values {
                "self.\(raw: field.name) = try columns.next()"
            }
        }
    }
    
    /// Generates a memberwise initializer for the model
    private static func memberwiseInit(
        for model: GeneratedModel
    ) -> InitializerDeclSyntax {
        return InitializerDeclSyntax(
            signature: FunctionSignatureSyntax(
                parameterClause: FunctionParameterClauseSyntax(
                    parameters: FunctionParameterListSyntax(
                        model.fields.values.positional()
                            .map { (position, field) in
                                FunctionParameterSyntax(
                                    firstName: .identifier(field.name),
                                    type: IdentifierTypeSyntax(name: .identifier(field.type)),
                                    trailingComma: position == .last ? nil : TokenSyntax.commaToken()
                                )
                            }
                    )
                )
            )
        ) {
            for field in model.fields.values {
                "self.\(raw: field.name) = \(raw: field.name)"
            }
        }
    }
    
    /// Generates a typealias for the query so the Query<Input, Output> does
    /// not have to be typed everytime it's referenced since it can get quite long
    /// and repetitive.
    private static func typealiasFor(query: GeneratedQuery) throws -> TypeAliasDeclSyntax {
        let name = "\(query.name.capitalizedFirst)Query"
        let input = query.input.map{ "DB.\($0.description)" } ?? "()"
        let output = query.output.map{ "DB.\($0.description)" } ?? "()"
        return try TypeAliasDeclSyntax("typealias \(raw: name) = any Query<\(raw: input), \(raw: output)>")
    }
    
    /// Creates an extension that has the input struct fields deconstructed so the
    /// input struct does not have to be constructed every time.
    private static func extensionForInput(
        query: GeneratedQuery,
        input: GeneratedModel
    ) throws -> ExtensionDeclSyntax {
        try ExtensionDeclSyntax("extension Query where Input == DB.\(raw: input.name)") {
            let parameters = input.fields.map { parameter in
                "\(parameter.key): \(parameter.value.type)"
            }.joined(separator: ", ")
            
            let args = input.fields.map { parameter in
                "\(parameter.key): \(parameter.key)"
            }.joined(separator: ", ")
            
            """
            func execute(\(raw: parameters)) async throws -> Output {
                try await execute(with: DB.\(raw: input.name)(\(raw: args)))
            }
            """
        }
    }
    
    private static func variableDecl(
        binding: Keyword = .let,
        name: String,
        type: String
    ) -> VariableDeclSyntax {
        VariableDeclSyntax(
            .let,
            name: "\(raw: name)",
            type: TypeAnnotationSyntax(
                type: IdentifierTypeSyntax(name: .identifier(type))
            )
        )
    }
    
    private static func stringLiteral(
        of contents: String,
        multiline: Bool = false
    ) -> StringLiteralExprSyntax {
        let openingQuote: TokenSyntax = multiline
            ? .multilineStringQuoteToken(trailingTrivia: .newline)
            : .singleQuoteToken()
        
        let closingQuote: TokenSyntax = multiline
            ? .multilineStringQuoteToken(leadingTrivia: .newline)
            : .singleQuoteToken()
        
        let segments: StringLiteralSegmentListSyntax
        if multiline {
            let lines = contents.split(separator: "\n")
            
            segments = StringLiteralSegmentListSyntax(
                lines
                    .enumerated()
                    .map { (i, s) in
                        .stringSegment(StringSegmentSyntax(
                            content: .stringSegment(s.description),
                            trailingTrivia: i == lines.count - 1 ? nil : .newline
                        ))
                    }
            )
        } else {
            segments = [.stringSegment(.init(content: .stringSegment(contents)))]
        }

        return StringLiteralExprSyntax(
            leadingTrivia: multiline ? Trivia.newline : nil,
            openingQuote: openingQuote,
            segments: segments,
            closingQuote: closingQuote,
            trailingTrivia: nil // Seems like a newline is added automatically?
        )
    }
    
    @CodeBlockItemListBuilder
    private static func bind(
        field: String?,
        isArray: Bool
    ) -> CodeBlockItemListSyntax {
        let paramName = if let field {
            "input.\(field)"
        } else {
            "input"
        }
        
        if isArray {
            """
            for element in \(raw: paramName) {
                try statement.bind(value: element)
            }
            """
        } else {
            "try statement.bind(value: \(raw: paramName))"
        }
    }
}

public typealias GenerationOptions = Set<GenerationOption>

public enum GenerationOption: Hashable {
    case namespace(String)
    case namespaceGeneratedModels
}

public struct GeneratedModel {
    let name: String
    let fields: OrderedDictionary<String, GeneratedField>
    /// Whether or not this was generated for a table
    let isTable: Bool
}

public struct GeneratedField {
    let name: String
    let type: String
    let isArray: Bool
}

public struct GeneratedQuery {
    let name: String
    let type: String
    let input: BuiltinOrGenerated?
    let output: BuiltinOrGenerated?
    let sourceSql: String
    let isReadOnly: Bool
}

public struct GeneratedResult<Decl> {
    let queries: [Decl]
    let inputs: [Decl]
    let outputs: [Decl]
}

public enum BuiltinOrGenerated: CustomStringConvertible {
    case builtin(String, isArray: Bool)
    case model(GeneratedModel)
    
    public var description: String {
        switch self {
        case .builtin(let builtin, let isArray):
            isArray ? "[\(builtin)]" : builtin
        case .model(let model):
            model.name
        }
    }
}
