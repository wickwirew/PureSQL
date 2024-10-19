import SwiftCompilerPlugin
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros
import Parser
import Schema

struct GenError: Error, CustomStringConvertible {
    let description: String
    
    init(_ description: String) {
        self.description = description
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
        
        return [
            DeclSyntax(StructDeclSyntax(name: "Schema") {
                for table in schema.tables.values {
                    StructDeclSyntax(name: "\(raw: table.name.capitalized)") {
                        for column in table.columns.values {
                            let isNonOptional = column.constraints
                                .contains { $0.isPkConstraint || $0.isNotNullConstraint }
                            
                            """
                            let \(raw: column.name): \(raw: column.type.swiftType)\(raw: isNonOptional ? "" : "?")
                            """
                        }
                    }
                }
            })
        ]
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

@main
struct SQLPlugin: CompilerPlugin {
    let providingMacros: [Macro.Type] = [
        SchemaMacro.self,
        QueryMacro.self,
    ]
}

extension TypeName {
    var swiftType: String {
        return switch self {
        case .int, .integer: "Int"
        case .tinyint: "Int8"
        case .smallint, .int2: "Int16"
        case .mediumint: "Int32"
        case .bigint, .int8: "Int64"
        case .unsignedBigInt: "UInt64"
        case .numeric, .decimal: "Double"
        case .boolean: "Boolean"
        case .date, .datetime: "Date"
        case .real, .float: "Float"
        case .double, .doublePrecision: "Double"
        case .character, .varchar, .varyingCharacter, .nativeCharacter, 
             .nvarchar, .text, .nchar, .clob: "String"
        case .blob: "Data"
        }
    }
}

struct LogError: Error, CustomStringConvertible {
    let description: String
}

