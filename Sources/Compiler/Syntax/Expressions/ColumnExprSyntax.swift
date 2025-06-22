//
//  ColumnExprSyntax.swift
//  Otter
//
//  Created by Wes Wickwire on 5/7/25.
//

struct ColumnExprSyntax: ExprSyntax, CustomStringConvertible {
    let id: SyntaxId
    let schema: IdentifierSyntax?
    let table: IdentifierSyntax?
    let column: Column
    
    enum Column: CustomStringConvertible {
        case column(IdentifierSyntax)
        case all(SourceLocation)
        
        var description: String {
            return switch self {
            case let .column(c): c.description
            case .all: "*"
            }
        }
        
        var location: SourceLocation {
            return switch self {
            case let .column(c): c.location
            case let .all(l): l
            }
        }
    }
    
    var description: String {
        let namespace = [schema, table]
            .compactMap { $0?.value }
            .joined(separator: ".")
        
        return namespace.isEmpty ? column.description : "\(namespace).\(column)"
    }
    
    var location: SourceLocation {
        let first = schema?.location ?? table?.location ?? column.location
        return first.spanning(column.location)
    }
    
    var isSingleColumn: Bool {
        guard case .column = column else { return false }
        return true
    }
    
    func accept<V: ExprSyntaxVisitor>(visitor: inout V) -> V.ExprOutput {
        return visitor.visit(self)
    }
}
