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
        return MessageID(domain: "SpyableMacro", id: message)
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
        
        guard let (queriesDict, migrationsSyntax) = findQueriesAndMigrations(from: s.memberBlock, in: context),
              let queriesSyntax = queriesDict.content.as(DictionaryElementListSyntax.self)
        else {
            context.addDiagnostics(from: GenError("Unable to resolve migrations and queries"), node: node)
            return []
        }
        
        let migrationsSource = try migrationsSyntax.elements
            .map {
                guard let source = $0.expression.as(StringLiteralExprSyntax.self) else {
                    throw GenError("Migrations must be string literals")
                }
                
                return source.segments.description
            }
        
        let queriesSource: [(name: String, source: String, syntax: StringLiteralExprSyntax)] = try queriesSyntax
            .map {
                guard let name = $0.key.as(StringLiteralExprSyntax.self),
                      let source = $0.value.as(StringLiteralExprSyntax.self)
                else {
                    throw GenError("Key/value must be string literals")
                }
                
                return (name.segments.description, source.segments.description, source)
            }
        
        var compiler = SchemaCompiler()
        for migration in migrationsSource {
            compiler.compile(migration)
        }
        
        var migrationsGenerator = SwiftMigrationsGenerator()
        migrationsSource.enumerated().forEach { migrationsGenerator.addMigration(number: $0.offset + 1, sql: $0.element) }
        let migrations = try migrationsGenerator.generateVariable(static: true)
        
        let statements: [DeclSyntax] = try queriesSource.flatMap { query in
            var compiler = QueryCompiler(schema: compiler.schema, pragmas: compiler.pragmas.featherPragmas)
            compiler.compile(query.source)
            
            var queriesGenerator = SwiftQueriesGenerator(
                schema: compiler.schema,
                statements: compiler.statements.map { $0.with(name: query.name[...]) },
                source: query.source
            )
            
            return try queriesGenerator.generateDeclarations()
        }
        
        return [DeclSyntax(migrations)] + statements
        
//        var schemaCompiler = SchemaCompiler()
//        let (schema, diags) = try schemaCompiler.compile(migrations)
//        
//        for _ in diags.diagnostics {
//            // TODO: Need syntax
//        }
//        
//        let compiledQueries = try queries.map {
//            var queryCompiler = QueryCompiler(schema: schema)
//            return ($0, try queryCompiler.compile($1), $1, $2)
//        }
//        
//        return compiledQueries.flatMap { (name, query, source, syntax) in
//            guard case let .row(.named(columns)) = query.0.output else { fatalError() }
//            
//            for diag in query.1.diagnostics {
//                context.diagnose(.init(
//                    node: syntax,
//                    message: MyMessage(diag.message)
//                ))
//            }
//            
//            return [
//                DeclSyntax(StructDeclSyntax(name: "\(raw: name)Query: DatabaseQuery") {
//                    "typealias Output = [\(raw: name)]"
//                    "typealias Context = Connection"
//                    
//                    """
//                    func statement(in connection: borrowing Connection, with input: Input) throws(FeatherError) -> Statement {
//                        var statement = try Statement(\"\"\"\n\(raw: source)\n\"\"\", connection: connection)
//                        \(raw: query.0.inputs.map { "try statement.bind(value: input.\($0.name))" }.joined(separator: "\n"))
//                        return statement
//                    }
//                    """
//                    
//                    DeclSyntax(StructDeclSyntax(name: "Input") {
//                        for input in query.0.inputs {
//                            """
//                            let \(raw: input.name): \(raw: input.type.swiftType)
//                            """
//                        }
//                    })
//                }),
//                
//                DeclSyntax(StructDeclSyntax(name: "\(raw: name): RowDecodable") {
//                    for (column, type) in columns {
//                        """
//                        let \(raw: column): \(raw: type.swiftType)
//                        """
//                    }
//                    
//                    """
//                    init(row: borrowing Row) throws(FeatherError) {
//                        var columns = cursor.indexedColumns()
//                        \(raw: columns.map { "self.\($0.key) = try columns.next()" }.joined(separator: "\n"))
//                    }
//                    """
//                })
//            ]
//        }
    }
    
    private static func findQueriesAndMigrations(
        from members: MemberBlockSyntax,
        in context: some MacroExpansionContext
    ) -> (DictionaryExprSyntax, ArrayExprSyntax)? {
        var queries: DictionaryExprSyntax?
        var migrations: ArrayExprSyntax?
        
        for member in members.members {
            guard let decl = member.decl.as(VariableDeclSyntax.self) else { continue }
            
            for binding in decl.bindings {
                guard let ident = binding.pattern.as(IdentifierPatternSyntax.self)?.identifier.text else { break }
                
                if ident == "queries" {
                    if let value = getBindingExpr(as: DictionaryExprSyntax.self, from: binding, in: context) {
                        queries = value
                    } else {
                        context.addDiagnostics(from: GenError("Unable to find queries dictionary"), node: binding)
                    }
                } else if ident == "migrations" {
                    if let value = getBindingExpr(as: ArrayExprSyntax.self, from: binding, in: context) {
                        migrations = value
                    } else {
                        context.addDiagnostics(from: GenError("Unable to find migrations array"), node: binding)
                    }
                }
                
                if let queries, let migrations {
                    return (queries, migrations)
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

struct LogError: Error, CustomStringConvertible {
    let description: String
}

extension Type {
    var swiftType: String {
        switch self {
        case let .nominal(name):
            return switch name.uppercased() {
            case "REAL": "Double"
            case "INT": "Int"
            case "INTEGER": "Int"
            case "TEXT": "String"
            default: "Any"
            }
        case let .optional(ty):
            return "\(ty.swiftType)?"
        case .var, .fn, .row, .error:
            return "Any"
        }
    }
}
