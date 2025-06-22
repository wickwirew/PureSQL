//
//  QueryMacro.swift
//  Otter
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
              let binding = property.bindings.first,
              let identifier = binding.pattern.as(IdentifierPatternSyntax.self)?.identifier,
              binding.accessorBlock == nil
        else {
            return []
        }

        return [
            "get { return _\(raw: identifier.text.removingQuerySuffix()) }",
        ]
    }
}
