//
//  QueryMacro.swift
//  PureSQL
//
//  Created by Wes Wickwire on 5/10/25.
//

import Compiler
import SwiftCompilerPlugin
import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

public struct QueryMacro: AccessorMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingAccessorsOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [AccessorDeclSyntax] {
        guard let property = declaration.as(VariableDeclSyntax.self),
              let typeName = property.typeName?.removingQuerySuffix().lowercaseFirst
        else {
            return []
        }

        return [
            "get { return _\(raw: typeName) }",
        ]
    }
}
