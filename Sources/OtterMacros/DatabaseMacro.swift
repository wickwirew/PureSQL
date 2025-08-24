//
//  DatabaseMacro.swift
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
        
        for variable in variables.values {
            guard let queryMacro = variable.queryMacroInputsIfIsQuery(in: context),
                  let typeName = variable.typeName?.removingQuerySuffix() else { continue }
            
            let (statement, diagnostics) = compiler.compile(
                query: queryMacro.source,
                named: typeName,
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
        
        let swift = SwiftLanguage(
            options: GenerationOptions(
                databaseName: ""
            )
        )
        
        let (generatedTables, generatedQueries) = try swift.assemble(
            queries: [(nil, queries)],
            schema: compiler.schema
        )
        
        let raw = swift.macro(
            databaseName: structDecl.name.text,
            tables: generatedTables,
            queries: generatedQueries.flatMap(\.1),
            addConnection: variables["connection"] == nil
        )
        
        return raw.map { decl in
            "\(raw: decl)"
        }
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
        extension \(raw: type.trimmedDescription): Otter.Database {}
        """
        return [decl.cast(ExtensionDeclSyntax.self)]
    }
}
