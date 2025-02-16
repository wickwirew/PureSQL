//
//  SwiftMigrationsGenerator.swift
//  Feather
//
//  Created by Wes Wickwire on 2/16/25.
//

import SwiftSyntax
import SwiftSyntaxBuilder

public struct SwiftMigrationsGenerator {
    private var migrations: [FunctionCallExprSyntax] = []
    
    public init() {}
    
    public func generate() throws -> SourceFileSyntax {
        return try SourceFileSyntax {
            try VariableDeclSyntax("var migrations: [Migration]") {
                ArrayExprSyntax(
                    expressions: migrations.map { SwiftSyntax.ExprSyntax($0) }
                )
            }
        }
    }
    
    public mutating func addMigration(number: Int, sql: String) {
        let function = FunctionCallExprSyntax(
            calledExpression: DeclReferenceExprSyntax(
                baseName: .identifier("Migration")
            ),
            leftParen: .leftParenToken(),
            arguments: LabeledExprListSyntax {
                LabeledExprSyntax(
                    label: "number",
                    colon: .colonToken(),
                    expression: IntegerLiteralExprSyntax(number),
                    trailingComma: nil
                )
                
                LabeledExprSyntax(
                    label: "sql",
                    colon: .colonToken(),
                    expression: StringLiteralExprSyntax(content: sql),
                    trailingComma: nil
                )
            },
            rightParen: .rightParenToken()
        )
        
        migrations.append(function)
    }
}
