//
//  BindParameterSyntax.swift
//  Otter
//
//  Created by Wes Wickwire on 5/7/25.
//

struct BindParameterSyntax: ExprSyntax, Hashable, CustomStringConvertible {
    let id: SyntaxId
    let kind: Kind
    let index: Index
    let location: SourceLocation
    
    typealias Index = Int
    
    enum Kind: Hashable {
        case questionMark
        case number(Int)
        case colon(IdentifierSyntax)
        case at(IdentifierSyntax)
        case tcl([IdentifierSyntax], suffix: IdentifierSyntax?)
        
        var name: String? {
            return switch self {
            case .questionMark, .number: nil
            case let .colon(s): s.description
            case let .at(s): s.description
            case let .tcl(s, suffix): s.map(\.value).joined() + (suffix?.description ?? "")
            }
        }
    }
    
    var name: String? {
        kind.name
    }
    
    var description: String {
        return switch kind {
        case .questionMark: "?"
        case let .number(n): "?\(n)"
        case let .colon(s): ":\(s)"
        case let .at(s): "@\(s)"
        case let .tcl(s, suffix): "$\(s.map(\.value).joined(separator: "::"))\(suffix.map { "(\($0))" } ?? "")"
        }
    }
    
    func accept<V: ExprSyntaxVisitor>(visitor: inout V) -> V.ExprOutput {
        return visitor.visit(self)
    }
}
