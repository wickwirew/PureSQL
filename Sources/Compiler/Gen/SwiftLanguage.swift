//
//  SwiftLanguage.swift
//  Feather
//
//  Created by Wes Wickwire on 4/29/25.
//

import SwiftSyntax
import SwiftSyntaxBuilder

public struct SwiftLanguage: Language {
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
            case "BLOB": "Data"
            default: "SQLAny"
            }
        case let .optional(ty): "\(builtinType(for: ty))?"
        case let .row(.unknown(ty)): "[\(builtinType(for: ty))]"
        case .var, .fn, .row, .error: "Any"
        case .alias(_, let alias): alias.description
        }
    }
    
    public static func file(
        imports: [String],
        databaseName: String,
        migrations: [String],
        tables: [GeneratedModel],
        queries: [GeneratedQuery],
        options: GenerationOptions
    ) throws -> String {
        let file = try SourceFileSyntax {
            try ImportDeclSyntax("import Foundation")
            try ImportDeclSyntax("import Feather")
            
            for `import` in imports {
                try ImportDeclSyntax("import \(raw: `import`)")
            }

            for table in tables {
                try declaration(for: table, isOutput: true, options: options)
            }
            
            if !options.contains(.namespaceGeneratedModels) {
                for query in queries {
                    for model in try modelsFor(query: query, options: options) {
                        model
                    }
                }
            }
            
            try StructDeclSyntax("struct \(raw: databaseName): Database") {
                "let connection: any Feather.Connection"
                
                try declaration(for: migrations, options: options)
                
                for query in queries {
                    if options.contains(.namespaceGeneratedModels) {
                        for model in try modelsFor(query: query, options: options) {
                            model
                        }
                    }
                    
                    try declaration(for: query, databaseName: databaseName, options: options)
                }
            }
            
            for query in queries {
                try typealiasFor(query: query, databaseName: databaseName, options: options)
                
                if let input = query.input, case let .model(model) = input {
                    try inputExtension(for: query, input: model, databaseName: databaseName, options: options)
                }
            }
        }
        
        return file.formatted().description
    }
    
    public static func macro(
        databaseName: String,
        tables: [GeneratedModel],
        queries: [GeneratedQuery],
        options: GenerationOptions,
        addConnection: Bool
    ) throws -> [DeclSyntax] {
        var decls: [DeclSyntax] = []
        
        if addConnection {
            decls.append("let connection: any Feather.Connection")
        }
        
        for table in tables {
            try decls.append(declaration(for: table, isOutput: true, options: options))
        }
        
        // Always do this at the top level since it will automatically namespaced under the
        // struct that the macro is attached too.
        for query in queries {
            try decls.append(contentsOf: modelsFor(query: query, options: options))
            try decls.append(declaration(for: query, underscoreName: true, databaseName: databaseName, options: options))
            try decls.append(DeclSyntax(dbTypealiasFor(query: query, databaseName: databaseName, options: options)))
            try decls.append(DeclSyntax(typealiasFor(query: query, databaseName: databaseName, options: options)))
        }
        
        // TODO: Generate extensions if this can be done.
        
        return decls
    }
    
    private static func modelsFor(
        query: GeneratedQuery,
        options: GenerationOptions
    ) throws -> [DeclSyntax] {
        var decls: [DeclSyntax] = []
        
        if case let .model(model) = query.input, !model.isTable {
            try decls.append(declaration(for: model, isOutput: false, options: options))
        }
        
        if case let .model(model) = query.output, !model.isTable {
            try decls.append(declaration(for: model, isOutput: true, options: options))
        }
        
        return decls
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
        underscoreName: Bool = false,
        databaseName: String,
        options: GenerationOptions
    ) throws -> DeclSyntax {
        let inputTypeName = inputTypeName(for: query, databaseName: databaseName)
        let outputTypeName = outputTypeName(for: query, databaseName: databaseName)
        let queryTypeName = "AnyDatabaseQuery<\(inputTypeName), \(outputTypeName)>"
        let variableName = underscoreName ? "_\(query.name)" : query.name
        
        let query = try VariableDeclSyntax("var \(raw: variableName): \(raw: queryTypeName)") {
            FunctionCallExprSyntax(
                calledExpression: DeclReferenceExprSyntax(
                    baseName: .identifier("AnyDatabaseQuery<\(inputTypeName), \(outputTypeName)>")
                ),
                leftParen: .leftParenToken(),
                arguments: LabeledExprListSyntax {
                    let hasWatchingTables = query.isReadOnly
                    
                    LabeledExprSyntax(
                        leadingTrivia: hasWatchingTables ? .newline : nil,
                        label: nil,
                        colon: nil,
                        expression: DeclReferenceExprSyntax(
                            baseName: query.isReadOnly ? ".read" : ".write"
                        ),
                        trailingComma: TokenSyntax.commaToken()
                    )
                    LabeledExprSyntax(
                        leadingTrivia: hasWatchingTables ? .newline : nil,
                        label: TokenSyntax.identifier("in"),
                        colon: TokenSyntax.colonToken(),
                        expression: DeclReferenceExprSyntax(baseName: .identifier("connection")),
                        trailingComma: hasWatchingTables ? TokenSyntax.commaToken() : nil
                    )
                    
                    if hasWatchingTables {
                        LabeledExprSyntax(
                            leadingTrivia: .newline,
                            label: TokenSyntax.identifier("watchingTables"),
                            colon: TokenSyntax.colonToken(),
                            expression: ArrayExprSyntax {
                                if query.isReadOnly {
                                    for table in query.usedTableNames {
                                        ArrayElementSyntax(expression: StringLiteralExprSyntax(content: table.description))
                                    }
                                }
                            },
                            trailingComma: nil,
                            trailingTrivia: .newline
                        )
                    }
                },
                rightParen: .rightParenToken(),
                trailingClosure: ClosureExprSyntax(
                    signature: ClosureSignatureSyntax(
                        parameterClause: .simpleInput(.init {
                            ClosureShorthandParameterSyntax(name: "input")
                            ClosureShorthandParameterSyntax(name: "tx")
                        })
                    )
                ) {
                    let sql = stringLiteral(of: query.sourceSql, multiline: true)
                    let statementBinding: TokenSyntax = .keyword(query.input == nil ? .let : .var)
                    "\(statementBinding) statement = try Feather.Statement(\(sql), \ntransaction: tx\n)"

                    if let input = query.input {
                        switch input {
                        case let .builtin(_, isArray, encodedAs):
                            bind(field: nil, encodeToType: encodedAs, isArray: isArray)
                        case .model(let model):
                            for field in model.fields.values {
                                bind(field: field.name, encodeToType: field.encodedAsType, isArray: field.isArray)
                            }
                        }
                    }

                    if query.output == nil {
                        "_ = try statement.step()"
                    } else {
                        switch query.outputCardinality {
                        case .single:
                            "return try statement.fetchOne()"
                        case .many:
                            "return try statement.fetchAll()"
                        }
                    }
                }
            )
        }
        
        return DeclSyntax(query)
    }
    
    private static func typealiasFor(
        query: GeneratedQuery,
        databaseName: String,
        options: GenerationOptions
    ) throws -> TypeAliasDeclSyntax {
        let namespace = options.contains(.namespaceGeneratedModels)
        let inputTypeName = inputTypeName(for: query, namespaced: namespace, databaseName: databaseName)
        let outputTypeName = outputTypeName(for: query, namespaced: namespace, databaseName: databaseName)
        return try TypeAliasDeclSyntax(
            "typealias \(raw: query.name.capitalizedFirst) = Query<\(raw: inputTypeName), \(raw: outputTypeName)>"
        )
    }
    
    private static func dbTypealiasFor(
        query: GeneratedQuery,
        databaseName: String,
        options: GenerationOptions
    ) throws -> TypeAliasDeclSyntax {
        let namespace = options.contains(.namespaceGeneratedModels)
        let inputTypeName = inputTypeName(for: query, namespaced: namespace, databaseName: databaseName)
        let outputTypeName = outputTypeName(for: query, namespaced: namespace, databaseName: databaseName)
        let name = query.name.capitalizedFirst.replacingOccurrences(of: "Query", with: "DatabaseQuery")
        return try TypeAliasDeclSyntax(
            "typealias \(raw: name) = AnyDatabaseQuery<\(raw: inputTypeName), \(raw: outputTypeName)>"
        )
    }
    
    private static func inputExtension(
        for query: GeneratedQuery,
        input: GeneratedModel,
        databaseName: String,
        options: GenerationOptions
    ) throws -> ExtensionDeclSyntax {
        let namespace = options.contains(.namespaceGeneratedModels)
        let inputTypeName = inputTypeName(for: query, namespaced: namespace, databaseName: databaseName)
        return try ExtensionDeclSyntax("extension Query where Input == \(raw: inputTypeName)") {
            let parameters = input.fields.map { parameter in
                "\(parameter.key): \(parameter.value.type)"
            }.joined(separator: ", ")
            
            let args = input.fields.map { parameter in
                "\(parameter.key): \(parameter.key)"
            }.joined(separator: ", ")
            
            """
            func execute(\(raw: parameters)) async throws -> Output {
                try await execute(with: \(raw: inputTypeName)(\(raw: args)))
            }
            """
        }
    }
    
    private static func inputTypeName(for query: GeneratedQuery, namespaced: Bool = false, databaseName: String) -> String {
        guard let input = query.input else { return "()" }
        return namespaced ? input.namespaced(to: databaseName) : input.description
    }
    
    private static func outputTypeName(for query: GeneratedQuery, namespaced: Bool = false, databaseName: String) -> String {
        if let output = query.output {
            let type = namespaced ? output.namespaced(to: databaseName) : output.description
            return switch query.outputCardinality {
            case .single: "\(type)?"
            case .many: "[\(type)]"
            }
        } else {
            return "()"
        }
    }
    
    private static func declaration(
        for model: GeneratedModel,
        isOutput: Bool,
        options: GenerationOptions
    ) throws -> DeclSyntax {
        let inheretance = InheritanceClauseSyntax {
            InheritedTypeSyntax(type: TypeSyntax("Hashable"))
            InheritedTypeSyntax(type: TypeSyntax("Sendable"))
            
            if model.fields["id"] != nil {
                InheritedTypeSyntax(type: TypeSyntax("Identifiable"))
            }
            
            if isOutput {
                InheritedTypeSyntax(type: TypeSyntax("Feather.RowDecodable"))
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
                            type: IdentifierTypeSyntax(name: "borrowing Feather.Row"),
                            trailingComma: TokenSyntax.commaToken()
                        ),
                        FunctionParameterSyntax(
                            firstName: "startingAt",
                            secondName: "start",
                            type: IdentifierTypeSyntax(name: "Int32")
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
            var index = 0
            for field in model.fields.values {
                switch field.type {
                case .builtin(_, _, let encodedAs):
                    if let encodedAs {
                        "self.\(raw: field.name) = try \(raw: field.type)(primitive: row.value(at: start + \(raw: index), as: \(raw: encodedAs).self))"
                    } else {
                        "self.\(raw: field.name) = try row.value(at: start + \(raw: index))"
                    }

                    let _ = index += 1
                case .model(let model):
                    "self.\(raw: field.name) = try \(raw: field.type)(row: row, startingAt: start + \(raw: index))"
                    let _ = index += model.fields.count
                }
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
                                    type: IdentifierTypeSyntax(name: .identifier(field.type.description)),
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
    
    private static func variableDecl(
        binding: Keyword = .let,
        name: String,
        type: BuiltinOrGenerated
    ) -> VariableDeclSyntax {
        VariableDeclSyntax(
            .let,
            name: "\(raw: name)",
            type: TypeAnnotationSyntax(
                type: IdentifierTypeSyntax(name: .identifier(type.description))
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
        encodeToType: String?,
        isArray: Bool
    ) -> CodeBlockItemListSyntax {
        let paramName = if let field {
            "input.\(field)"
        } else {
            "input"
        }
        
        let encode = if let encodeToType {
            ".encodeTo\(encodeToType)()"
        } else {
            ""
        }
        
        if isArray {
            """
            for element in \(raw: paramName) {
                try statement.bind(value: element\(raw: encode))
            }
            """
        } else {
            "try statement.bind(value: \(raw: paramName)\(raw: encode))"
        }
    }
}
