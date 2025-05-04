import Compiler
import SwiftCompilerPlugin
import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

struct GenError: Error, CustomStringConvertible {
    let description: String
    
    init(_ description: String) {
        self.description = description
    }
}

struct MyMessage: DiagnosticMessage {
    var message: String
    
    init(_ message: String) {
        self.message = message
    }
    
    var diagnosticID: MessageID {
        return MessageID(domain: "FeatherMacro", id: message)
    }
    
    var severity: DiagnosticSeverity {
        return .error
    }
}

public struct DatabaseMacro: MemberMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingMembersOf declaration: some DeclGroupSyntax,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        guard let s = declaration.as(StructDeclSyntax.self) else {
            context.addDiagnostics(from: GenError("@Database can only be applied to a struct"), node: declaration)
            return []
        }
        
        guard let (queriesSyntax, migrationsSyntax) = findQueriesAndMigrations(from: s.memberBlock, in: context) else {
            context.addDiagnostics(from: GenError("Unable to resolve migrations and queries"), node: node)
            return []
        }
        
        fatalError()
        
//        var compiler = Compiler()
//        var queries: [SwiftGenerator.Query] = []
//        
//        for (contents, syntax) in migrationsSyntax {
//            for diagnostic in compiler.compile(migration: contents).elements {
//                context.addDiagnostics(from: diagnostic, node: syntax)
//            }
//        }
//        
//        for (contents, syntax) in queriesSyntax {
//            let diagnostics = compiler.compile(queries: contents)
//            
//            for statement in compiler.queries {
//                guard let name = statement.name else { continue }
//                try queries.append(SwiftGenerator.query(statement: statement, name: name))
//            }
//            
//            for diagnostic in diagnostics.elements {
//                context.addDiagnostics(from: diagnostic, node: syntax)
//            }
//        }
//        
//        return queries.map(\.decls).flatMap(\.self)
    }
    
    private static func arrayStrings(
        _ syntax: ArrayExprSyntax,
        in context: some MacroExpansionContext
    ) -> [(String, StringLiteralExprSyntax)] {
        syntax.elements.compactMap { element in
            guard let source = element.expression.as(StringLiteralExprSyntax.self) else {
                context.addDiagnostics(from: GenError("Must be string literal"), node: element)
                return nil
            }
            
            return (source.segments.description, source)
        }
    }
    
    private static func findQueriesAndMigrations(
        from members: MemberBlockSyntax,
        in context: some MacroExpansionContext
    ) -> ([(String, StringLiteralExprSyntax)], [(String, StringLiteralExprSyntax)])? {
        var queries: ArrayExprSyntax?
        var migrations: ArrayExprSyntax?
        
        for member in members.members {
            guard let decl = member.decl.as(VariableDeclSyntax.self) else { continue }
            
            for binding in decl.bindings {
                guard let ident = binding.pattern.as(IdentifierPatternSyntax.self)?.identifier.text else { break }
                
                if ident == "queries" {
                    if let value = getBindingExpr(as: ArrayExprSyntax.self, from: binding, in: context) {
                        queries = value
                    } else {
                        context.addDiagnostics(from: GenError("Unable to find queries array"), node: binding)
                    }
                } else if ident == "migrations" {
                    if let value = getBindingExpr(as: ArrayExprSyntax.self, from: binding, in: context) {
                        migrations = value
                    } else {
                        context.addDiagnostics(from: GenError("Unable to find migrations array"), node: binding)
                    }
                }
                
                if let queries, let migrations {
                    return (arrayStrings(queries, in: context), arrayStrings(migrations, in: context))
                }
            }
        }
        
        return nil
    }
    
    private static func getBindingExpr<T: ExprSyntaxProtocol>(
        as t: T.Type,
        from binding: PatternBindingListSyntax.Element,
        in context: some MacroExpansionContext
    ) -> T? {
        guard let accessorBlock = binding.accessorBlock else {
            context.addDiagnostics(from: GenError("No accessor found"), node: binding)
            return nil
        }
        
        guard case let .getter(getter) = accessorBlock.accessors else {
            context.addDiagnostics(from: GenError("No getter"), node: binding)
            return nil
        }
        
        guard let ret = getter.last?.item.as(ReturnStmtSyntax.self) else {
            context.addDiagnostics(from: GenError("Can only only have just a return statement"), node: binding)
            return nil
        }
        
        return ret.expression?.as(T.self)
    }
}

public struct SchemaMacro: DeclarationMacro {
    public static func expansion(
        of node: some FreestandingMacroExpansionSyntax,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        return []
    }
}

public struct QueryMacro: ExpressionMacro {
    public static func expansion(
        of node: some FreestandingMacroExpansionSyntax, in context: some MacroExpansionContext
    ) throws -> ExprSyntax {
        let value = """
        {
        struct Foo {}
        return Foo()
        }()
        """
        
        return "\(raw: value)"
    }
}

public struct Schema2Macro: DeclarationMacro {
    public static func expansion(of node: some SwiftSyntax.FreestandingMacroExpansionSyntax, in context: some SwiftSyntaxMacros.MacroExpansionContext) throws -> [SwiftSyntax.DeclSyntax] {
        return []
    }
}

@main
struct SQLPlugin: CompilerPlugin {
    let providingMacros: [Macro.Type] = [
        SchemaMacro.self,
        QueryMacro.self,
        DatabaseMacro.self,
    ]
}
