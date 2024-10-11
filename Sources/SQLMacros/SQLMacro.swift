import SwiftCompilerPlugin
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros
import Parser
import Schema

/// Implementation of the `stringify` macro, which takes an expression
/// of any type and produces a tuple containing the value of that expression
/// and the source code that produced the value. For example
///
///     #stringify(x + y)
///
///  will expand to
///
///     (x + y, "x + y")
public struct StringifyMacro: ExpressionMacro {
    public static func expansion(
        of node: some FreestandingMacroExpansionSyntax,
        in context: some MacroExpansionContext
    ) -> ExprSyntax {
        guard let argument = node.argumentList.first?.expression else {
            fatalError("compiler bug: the macro does not have any arguments")
        }
        
        guard let string = argument.as(StringLiteralExprSyntax.self) else {
            fatalError("Not a string")
        }

        return ""
    }
}

public struct SchemaMacro: DeclarationMacro {
    public static func expansion(
        of node: some FreestandingMacroExpansionSyntax,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        guard let argument = node.argumentList.first?.expression else {
            fatalError("compiler bug: the macro does not have any arguments")
        }
        
        guard let string = argument.as(StringLiteralExprSyntax.self) else {
            fatalError("Not a string")
        }
        

        var state = try ParserState(string.segments.description)
        
        let table = try CreateTableParser()
            .parse(state: &state)
        
        guard case let .columns(columns) = table.kind else { return [] }
        
        let fields: String = columns.map { (_, column) in
            """
            let \(column.name): \(column.type.swiftType)\(column.constraints.contains{ $0.isNotNullConstraint || $0.isPkConstraint } ? "" : "?")
            """
        }
            .joined(separator: "\n")
        
        let decl: DeclSyntax = """
        struct \(raw: table.name.toUpperCamelCase()) {
            \(raw: fields)
        }
        """
        
        return [
            """
            struct Schema {
                \(decl)
            }
            """,
        ]
    }
}

@main
struct SQLPlugin: CompilerPlugin {
    let providingMacros: [Macro.Type] = [
        StringifyMacro.self,
        SchemaMacro.self,
    ]
}

extension StringProtocol {
    func toUpperCamelCase() -> String {
        guard let first = self.first?.uppercased() else { return "" }
        guard count > 1 else { return first }
        return "\(first)\(self[self.index(after: self.startIndex)..<self.endIndex])"
    }
}

extension Ty {
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
        case .date, .datetime: "Boolean"
        case .real, .float: "Float"
        case .double, .doublePrecision: "Double"
        case .character, .varchar, .varyingCharacter, .nativeCharacter, .nvarchar, .text, .nchar, .clob: "String"
        case .blob: "Data"
        }
    }
}
