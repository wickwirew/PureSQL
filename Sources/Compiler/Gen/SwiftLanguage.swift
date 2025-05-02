//
//  SwiftLanguage.swift
//  Feather
//
//  Created by Wes Wickwire on 4/29/25.
//

import SwiftSyntax
import SwiftSyntaxBuilder

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
                    if case let .model(model) = query.input, !model.isTable {
                        try declaration(for: model, isOutput: false, options: options)
                    }
                    
                    if case let .model(model) = query.output, !model.isTable {
                        try declaration(for: model, isOutput: true, options: options)
                    }
                    
                    try declaration(for: query, options: options)
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
        let inputTypeName = inputTypeName(for: query)
        let outputTypeName = outputTypeName(for: query)
        let queryTypeName = "DatabaseQuery<\(inputTypeName), \(outputTypeName)>"
        
        let query = try VariableDeclSyntax("var \(raw: query.name): \(raw: queryTypeName)") {
            FunctionCallExprSyntax(
                calledExpression: DeclReferenceExprSyntax(
                    baseName: .identifier("DatabaseQueryImpl<\(inputTypeName), \(outputTypeName)>")
                ),
                leftParen: .leftParenToken(),
                arguments: LabeledExprListSyntax {
                    LabeledExprSyntax(
                        label: nil,
                        colon: nil,
                        expression: DeclReferenceExprSyntax(
                            baseName: query.isReadOnly ? ".read" : ".write"
                        ),
                        trailingComma: TokenSyntax.commaToken()
                    )
                    LabeledExprSyntax(
                        label: TokenSyntax.identifier("database"),
                        colon: TokenSyntax.colonToken(),
                        expression: DeclReferenceExprSyntax(baseName: .identifier("database")),
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
                    "\(statementBinding) statement = try Feather.Statement(\(sql), \ntransaction: tx\n)"

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

                    if query.output == nil {
                        "_ = try statement.step()"
                    } else {
                        switch query.outputCardinality {
                        case .single:
                            "return try statement.fetchOne(of: Row.self)"
                        case .many:
                            "return try statement.fetchMany(of: Row.self)"
                        }
                    }
                }
            )
        }
        
        return DeclSyntax(query)
    }
    
    private static func outputTypeAlias(cardinality: Cardinality) throws -> TypeAliasDeclSyntax {
        switch cardinality {
        case .single:
            try TypeAliasDeclSyntax("typealias Output = Row?")
        case .many:
            try TypeAliasDeclSyntax("typealias Output = [Row]")
        }
    }
    
    private static func inputTypeName(for query: GeneratedQuery) -> String {
        return query.input?.description ?? "()"
    }
    
    private static func outputTypeName(for query: GeneratedQuery) -> String {
        if let output = query.output {
            switch query.outputCardinality {
            case .single: "\(output)?"
            case .many: "[\(output)]"
            }
        } else {
            "()"
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
    
    private static func typealiasDecl(
        named name: String,
        for type: BuiltinOrGenerated
    ) throws -> TypeAliasDeclSyntax {
        return switch type {
        case .builtin(let type, let isArray):
            try TypeAliasDeclSyntax("typealias \(raw: name) = \(raw: isArray ? "[\(type)]" : type)")
        case .model(let model):
            try TypeAliasDeclSyntax("typealias \(raw: name) = \(raw: model.name)")
        }
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
