//
//  DatabaseMacro.swift
//  Feather
//
//  Created by Wes Wickwire on 5/10/25.
//

import Compiler
import SwiftCompilerPlugin
import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

public struct DatabaseMacro {}

extension DatabaseMacro: MemberMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingMembersOf declaration: some DeclGroupSyntax,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        guard let structDecl = declaration.as(StructDeclSyntax.self) else {
            context.addDiagnostics(from: SyntaxError("@Database can only be applied to a struct"), node: declaration)
            return []
        }
        
        let variables = declaration.memberBlock.variableDecls()
        
        guard let migrations = variables["migrations"]?.asMigrationsArray(in: context) else {
            context.addDiagnostics(from: SyntaxError("Unable to resolve migrations"), node: node)
            return []
        }
        
        var compiler = Compiler()
        var queries: [Statement] = []
        
        for (migration, expr) in migrations {
            let (_, diagnostics) = compiler.compile(migration: migration)
            
            for diag in diagnostics {
                context.addDiagnostics(from: diag, node: expr)
            }
        }
        
        for (name, variable) in variables {
            guard let queryMacro = variable.queryMacroInputsIfIsQuery(in: context) else { continue }
            
            let (statement, diagnostics) = compiler.compile(
                query: queryMacro.source,
                named: name.removingQuerySuffix(),
                inputType: queryMacro.inputName,
                outputType: queryMacro.outputName
            )
            
            for diag in diagnostics {
                context.addDiagnostics(from: diag, node: variable)
            }
            
            if let statement {
                queries.append(statement)
            }
        }
        
        let (generatedTables, generatedQueries) = try SwiftLanguage.assemble(
            queries: [(nil, queries)],
            schema: compiler.schema
        )
        
        return try SwiftLanguage.macro(
            databaseName: structDecl.name.text,
            tables: generatedTables,
            queries: generatedQueries.flatMap(\.1),
            options: GenerationOptions(),
            addConnection: variables["connection"] == nil
        )
    }
}

extension DatabaseMacro: ExtensionMacro {
    public static func expansion(
        of node: AttributeSyntax,
        attachedTo declaration: some DeclGroupSyntax,
        providingExtensionsOf type: some TypeSyntaxProtocol,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [ExtensionDeclSyntax] {
        guard !protocols.isEmpty else { return [] }
        
        let decl: DeclSyntax = """
        extension \(raw: type.trimmedDescription): Feather.Database {}
        """
        return [decl.cast(ExtensionDeclSyntax.self)]
    }
}
