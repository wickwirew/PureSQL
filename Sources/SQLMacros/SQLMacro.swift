import SwiftCompilerPlugin
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros
import Parser
import Schema
import SwiftDiagnostics

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
                let queriesSyntax = queriesDict.content.as(DictionaryElementListSyntax.self) else {
            context.addDiagnostics(from: GenError("Unable to resolve migrations and queries"), node: node)
            return []
        }
        
        
        let migrations = try migrationsSyntax.elements
            .map {
                guard let source = $0.expression.as(StringLiteralExprSyntax.self) else {
                    throw GenError("Migrations must be string literals")
                }
                
                return source.segments.description
            }
            .joined(separator: "\n")
        
        let queries: [(name: String, source: String, syntax: StringLiteralExprSyntax)] = try queriesSyntax
            .map {
                guard let name = $0.key.as(StringLiteralExprSyntax.self),
                      let source = $0.value.as(StringLiteralExprSyntax.self) else {
                    throw GenError("Key/value must be string literals")
                }
                
                return (name.segments.description, source.segments.description, source)
            }
        
        let schema = try schema(from: migrations)
        
        let compiledQueries = try queries.map { ($0, try query(from: $1, schema: schema), $1, $2) }
        
        return compiledQueries.flatMap { (name, query, source, syntax) in
            guard case let .row(.named(columns)) = query.0.output else { fatalError() }
            
            for diag in query.1.diagnostics {
                context.diagnose(.init(
                    node: syntax,
                    message: MyMessage(diag.message)
                ))
            }
            
            return [
                DeclSyntax(StructDeclSyntax(name: "\(raw: name)Query") {
                    """
                    let input: Input
                    """
                    
                    DeclSyntax(StructDeclSyntax(name: "Input") {
                        for input in query.0.inputs {
                            """
                            let \(raw: input.name): \(raw: input.type.swiftType)
                            """
                        }
                    })
                }),
                
                DeclSyntax(StructDeclSyntax(name: "\(raw: name)") {
                    for (column, type) in columns {
                        """
                        let \(raw: column): \(raw: type.swiftType)
                        """
                    }
                })
            ]
        }
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
        guard let argument = node.argumentList.first?.expression else {
            throw GenError("No arguments")
        }
        
        guard let dictionary = argument.as(DictionaryExprSyntax.self), 
                let migrations = dictionary.content.as(DictionaryElementListSyntax.self) else {
            throw GenError("Migrations must be a dictionary literal, with both key/value as stirng literals")
        }
        
        let values: [(name: String, script: String)] = try migrations
            .map {
                guard let name = $0.key.as(StringLiteralExprSyntax.self),
                      let source = $0.value.as(StringLiteralExprSyntax.self) else {
                    throw GenError("Key/value must be string literals")
                }
                
                return (name.segments.description, source.segments.description)
            }
        
        let schema = try SchemaBuilder
            .build(from: values.map(\.script).joined(separator: ";"))
        
        return schema.tables.values.map { table in
            DeclSyntax(StructDeclSyntax(name: "\(raw: table.name.name.value.capitalized)") {
                for column in table.columns.values {
                    let isNonOptional = column.constraints
                        .contains { $0.isPkConstraint || $0.isNotNullConstraint }
                    
                    """
                    let \(raw: column.name): \(raw: column.type.swiftType)\(raw: isNonOptional ? "" : "?")
                    """
                }
            })
        }
    }
}

public struct QueryMacro: ExpressionMacro {
    public static func expansion(
        of node: some FreestandingMacroExpansionSyntax, in
        context: some MacroExpansionContext
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

extension TypeName {
    var swiftType: String {
        return "Never"
//        return switch self {
//        case .int, .integer: "Int"
//        case .tinyint: "Int8"
//        case .smallint, .int2: "Int16"
//        case .mediumint: "Int32"
//        case .bigint, .int8: "Int64"
//        case .unsignedBigInt: "UInt64"
//        case .numeric, .decimal: "Double"
//        case .boolean: "Boolean"
//        case .date, .datetime: "Date"
//        case .real, .float: "Float"
//        case .double, .doublePrecision: "Double"
//        case .character, .varchar, .varyingCharacter, .nativeCharacter, 
//             .nvarchar, .text, .nchar, .clob: "String"
//        case .blob: "Data"
//        }
    }
}

struct LogError: Error, CustomStringConvertible {
    let description: String
}

extension Ty {
    var swiftType: String {
        switch self {
        case .nominal(let name):
            return switch name.uppercased() {
            case "REAL": "Double"
            case "INT": "Int"
            case "INTEGER": "Int"
            case "TEXT": "String"
            default: "Any"
            }
        case .optional(let ty):
            return "\(ty.swiftType)?"
        case .var, .fn, .row, .error:
            return "Any"
        }
    }
}
