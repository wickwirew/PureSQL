//
//  SwiftLanguage.swift
//  Otter
//
//  Created by Wes Wickwire on 4/29/25.
//

import SwiftSyntax
import SwiftSyntaxBuilder

public struct SwiftLanguage: Language {
    public static func queryTypeName(
        input: String,
        output: String
    ) -> String {
        return "AnyDatabaseQuery<\(input), \(output)>"
    }
    
    public static func inputTypeName(input: BuiltinOrGenerated?) -> String {
        return input?.description ?? "()"
    }
    
    public static func outputTypeName(
        output: BuiltinOrGenerated?,
        cardinality: Cardinality
    ) -> String {
        if let type = output?.description {
            return switch cardinality {
            case .single: "\(type)?"
            case .many: "[\(type)]"
            }
        } else {
            return "()"
        }
    }
    
    public static func interpolatedQuestionMarks(for param: String) -> String {
        return "\\(\(param).sqlQuestionMarks)"
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
        case let .alias(_, alias):
            switch alias {
            case let .explicit(type):
                type.description
            case let .hint(hint):
                switch hint {
                case .bool: "Bool"
                }
            }
        }
    }
    
    public static func file(
        migrations: [String],
        tables: [GeneratedModel],
        queries: [(String?, [GeneratedQuery])],
        options: GenerationOptions
    ) throws -> String {
        let allQueries = queries.flatMap(\.1)
        
        let file = try SourceFileSyntax {
            try ImportDeclSyntax("import Foundation")
            try ImportDeclSyntax("import Otter")
            
            for `import` in options.imports {
                try ImportDeclSyntax("import \(raw: `import`)")
            }
            
            for table in tables {
                try declaration(for: table, isOutput: true, options: options)
            }
            
            for query in allQueries {
                for model in try modelsFor(query: query, options: options) {
                    model
                }
            }
            
            for (namespace, queries) in queries {
                if let namespace {
                    try queriesProtocol(name: namespace, queries: queries)
                    try queriesNoop(name: namespace, queries: queries)
                    try queriesImpl(name: namespace, queries: queries)
                }
            }
            
            try StructDeclSyntax("struct \(raw: options.databaseName): Database") {
                "let connection: any Otter.Connection"
                
                try declaration(for: migrations, options: options)
                
                for (namespace, queries) in queries {
                    if let namespace {
                        try queriesVariable(name: namespace, queries: queries)
                    } else {
                        // Generate queries with `nil` namespace which would make it global.
                        // This is really only used by the macro since it doesnt have file names
                        // which really wont happen here but still implement it for completeness.
                        for query in queries {
                            try declaration(for: query, databaseName: options.databaseName, options: options)
                        }
                    }
                }
            }
            
            for query in allQueries {
                try typealiasFor(query: query)
                
                if let input = query.input, case let .model(model) = input {
                    try inputExtension(for: query, input: model)
                }
            }
        }
        
        return file.formatted().description
    }
    
    /// Called by the actual Swift macro since it doesnt generate an entire
    /// file and requires a little extra treatment
    public static func macro(
        databaseName: String,
        tables: [GeneratedModel],
        queries: [GeneratedQuery],
        options: GenerationOptions,
        addConnection: Bool
    ) throws -> [DeclSyntax] {
        var decls: [DeclSyntax] = []
        
        if addConnection {
            decls.append("let connection: any Otter.Connection")
        }
        
        for table in tables {
            try decls.append(declaration(for: table, isOutput: true, options: options))
        }
        
        // Always do this at the top level since it will automatically namespaced under the
        // struct that the macro is attached too.
        for query in queries {
            try decls.append(contentsOf: modelsFor(query: query, options: options))
            try decls.append(declaration(for: query, underscoreName: true, databaseName: databaseName, options: options))
            try decls.append(DeclSyntax(dbTypealiasFor(query: query)))
            try decls.append(DeclSyntax(typealiasFor(query: query)))
        }
        
        // TODO: Generate extensions if this can be done.
        
        return decls
    }
    
    /// Generates the variable for the namespaced queries object within the database struct
    private static func queriesVariable(
        name: String,
        queries: [GeneratedQuery]
    ) throws -> DeclSyntax {
        let typeName = "\(name)Impl"
        
        let variable = try VariableDeclSyntax("var \(raw: name.lowercaseFirst): \(raw: typeName)") {
            "\(raw: typeName)(connection: connection)"
        }
        
        return DeclSyntax(variable)
    }
    
    /// Of the models needed to be generated for a query
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
    
    /// The migrations variable
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
    
    /// Generates the expression to initialize the query.
    ///
    /// ```swift
    /// var theQuery: AnyDatabaseQuery<In, Out> { ... }
    /// ```
    private static func declaration(
        for query: GeneratedQuery,
        underscoreName: Bool = false,
        databaseName: String,
        options: GenerationOptions
    ) throws -> DeclSyntax {
        let variableName = underscoreName ? "_\(query.variableName)" : query.variableName
        
        let query = try VariableDeclSyntax("var \(raw: variableName): \(raw: query.typeName)") {
            try queryExpression(for: query)
        }
        
        return DeclSyntax(query)
    }
    
    /// Generates the expression to initialize the query.
    ///
    /// ```swift
    /// AnyDatabaseQuery<In, Out>(...)
    /// ```
    private static func queryExpression(for query: GeneratedQuery) throws -> SwiftSyntax.ExprSyntax {
        let value = FunctionCallExprSyntax(
            calledExpression: DeclReferenceExprSyntax(
                baseName: .identifier(query.typeName)
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
                "\(statementBinding) statement = try Otter.Statement(\(sql), \ntransaction: tx\n)"
                
                if let input = query.input {
                    switch input {
                    case let .builtin(_, isArray, encodedAs):
                        bind(field: nil, encodeToType: encodedAs, isArray: isArray)
                    case let .model(model):
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
        
        return SwiftSyntax.ExprSyntax(value)
    }
    
    /// The namespaced queries protocol
    private static func queriesProtocol(
        name: String,
        queries: [GeneratedQuery]
    ) throws -> DeclSyntax {
        let protocl = try ProtocolDeclSyntax("protocol \(raw: name)") {
            for query in queries {
                let associatedType = query.name.capitalizedFirst
                "associatedtype \(raw: associatedType): \(raw: query.typealiasName)"
                "var \(raw: query.variableName): \(raw: associatedType) { get }"
            }
        }
        
        return DeclSyntax(protocl)
    }
    
    /// The namespaced queries protocol implementation
    private static func queriesImpl(
        name: String,
        queries: [GeneratedQuery]
    ) throws -> DeclSyntax {
        let strct = try StructDeclSyntax("struct \(raw: name)Impl: \(raw: name)") {
            "let connection: any Connection"
            
            for query in queries {
                try VariableDeclSyntax("var \(raw: query.variableName): \(raw: query.typeName)") {
                    try queryExpression(for: query)
                }
            }
        }
        
        return DeclSyntax(strct)
    }
    
    /// Generates the no-op implementation of the queries.
    private static func queriesNoop(
        name: String,
        queries: [GeneratedQuery]
    ) throws -> DeclSyntax {
        let strct = try StructDeclSyntax("struct \(raw: name)Noop: \(raw: name)") {
            for query in queries {
                "let \(raw: query.variableName): AnyQuery<\(raw: query.inputName), \(raw: query.outputName)>"
            }
            
            InitializerDeclSyntax(
                signature: FunctionSignatureSyntax(
                    parameterClause: FunctionParameterClauseSyntax(
                        parameters: FunctionParameterListSyntax(
                            queries.positional()
                                .map { position, query in
                                    FunctionParameterSyntax(
                                        leadingTrivia: position.isFirst ? .newline : nil,
                                        firstName: .identifier(query.variableName),
                                        type: IdentifierTypeSyntax(name: .identifier("any \(query.typealiasName)")),
                                        defaultValue: InitializerClauseSyntax(value: DeclReferenceExprSyntax(baseName: TokenSyntax.identifier("Queries.Just()"))),
                                        trailingComma: position .isLast ? nil : TokenSyntax.commaToken(),
                                        trailingTrivia: .newline
                                    )
                                }
                        )
                    )
                )
            ) {
                for query in queries {
                    "self.\(raw: query.variableName) = \(raw: query.variableName).eraseToAnyQuery()"
                }
            }
        }
        
        return DeclSyntax(strct)
    }
    
    private static func typealiasFor(query: GeneratedQuery) throws -> TypeAliasDeclSyntax {
        return try TypeAliasDeclSyntax(
            "typealias \(raw: query.typealiasName) = Query<\(raw: query.inputName), \(raw: query.outputName)>"
        )
    }
    
    private static func dbTypealiasFor(query: GeneratedQuery) throws -> TypeAliasDeclSyntax {
        let name = query.typealiasName.replacingOccurrences(of: "Query", with: "DatabaseQuery")
        return try TypeAliasDeclSyntax(
            "typealias \(raw: name) = AnyDatabaseQuery<\(raw: query.inputName), \(raw: query.outputName)>"
        )
    }
    
    private static func inputExtension(
        for query: GeneratedQuery,
        input: GeneratedModel
    ) throws -> ExtensionDeclSyntax {
        return try ExtensionDeclSyntax("extension Query where Input == \(raw: query.inputName)") {
            let parameters = input.fields.map { parameter in
                "\(parameter.key): \(parameter.value.type)"
            }.joined(separator: ", ")
            
            let args = input.fields.map { parameter in
                "\(parameter.key): \(parameter.key)"
            }.joined(separator: ", ")
            
            """
            func execute(\(raw: parameters)) async throws -> Output {
                try await execute(with: \(raw: query.inputName)(\(raw: args)))
            }
            """
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
                InheritedTypeSyntax(type: TypeSyntax("Otter.RowDecodable"))
            }
        }
        
        let dynamicLookupTables = model.fields.values.compactMap { value -> (String, GeneratedModel)? in
            guard case let .model(model) = value.type else { return nil }
            return (value.name, model)
        }
        
        let addDynamicLookup = isOutput && !dynamicLookupTables.isEmpty && model.fields.count > 1
        
        let strct = StructDeclSyntax(
            attributes: AttributeListSyntax {
                if addDynamicLookup {
                    let attr: AttributeSyntax = "@dynamicMemberLookup"
                    attr.with(\.trailingTrivia, .newline)
                }
            },
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
            
            if addDynamicLookup {
                for (fieldName, table) in dynamicLookupTables {
                    dynamicMemberLookup(fieldName: fieldName, typeName: table.name)
                }
            }
        }
        
        return DeclSyntax(strct)
    }
    
    private static func dynamicMemberLookup(
        fieldName: String,
        typeName: String
    ) -> SubscriptDeclSyntax {
        return SubscriptDeclSyntax(
            subscriptKeyword: TokenSyntax.keyword(.subscript)
                .with(\.trailingTrivia, .spaces(0)),
            genericParameterClause: GenericParameterClauseSyntax {
                GenericParameterSyntax(name: "Value")
            },
            parameterClause: FunctionParameterClauseSyntax(
                parameters: [
                    FunctionParameterSyntax(
                        firstName: "dynamicMember",
                        secondName: "dynamicMember",
                        type: IdentifierTypeSyntax(name: "KeyPath<\(raw: typeName), Value>"),
                        trailingComma: nil
                    ),
                ]
            ),
            returnClause: ReturnClauseSyntax(type: IdentifierTypeSyntax(name: "Value")),
            accessorBlock: AccessorBlockSyntax(accessors: .getter(CodeBlockItemListSyntax {
                SubscriptCallExprSyntax(
                    calledExpression: DeclReferenceExprSyntax(baseName: TokenSyntax.identifier(fieldName)),
                    arguments: LabeledExprListSyntax {
                        LabeledExprSyntax(
                            label: "keyPath",
                            colon: TokenSyntax.colonToken(),
                            expression: DeclReferenceExprSyntax(baseName: "dynamicMember"),
                            trailingComma: nil
                        )
                    }
                )
            }))
        )
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
                            type: IdentifierTypeSyntax(name: "borrowing Otter.Row"),
                            trailingComma: TokenSyntax.commaToken()
                        ),
                        FunctionParameterSyntax(
                            firstName: "startingAt",
                            secondName: "start",
                            type: IdentifierTypeSyntax(name: "Int32")
                        ),
                    ]
                ),
                effectSpecifiers: FunctionEffectSpecifiersSyntax(
                    throwsClause: ThrowsClauseSyntax(
                        throwsSpecifier: TokenSyntax.keyword(.throws),
                        leftParen: TokenSyntax.leftParenToken(),
                        type: TypeSyntax("OtterError"),
                        rightParen: TokenSyntax.rightParenToken()
                    )
                )
            )
        ) {
            var index = 0
            for field in model.fields.values {
                switch field.type {
                case let .builtin(_, _, encodedAs):
                    if let encodedAs {
                        "self.\(raw: field.name) = try \(raw: field.type)(primitive: row.value(at: start + \(raw: index), as: \(raw: encodedAs).self))"
                    } else {
                        "self.\(raw: field.name) = try row.value(at: start + \(raw: index))"
                    }
                    
                    let _ = index += 1
                case let .model(model):
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
                            .map { position, field in
                                FunctionParameterSyntax(
                                    firstName: .identifier(field.name),
                                    type: IdentifierTypeSyntax(name: .identifier(field.type.description)),
                                    trailingComma: position .isLast ? nil : TokenSyntax.commaToken()
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
                    .map { i, s in
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
