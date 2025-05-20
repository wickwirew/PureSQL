//
//  BindParameterSyntax.swift
//  Feather
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
            case .colon(let s): s.description
            case .at(let s): s.description
            case .tcl(let s, let suffix): s.map(\.value).joined() + (suffix?.description ?? "")
            }
        }
    }
    
    var name: String? {
        kind.name
    }
    
    var description: String {
        return switch kind {
        case .questionMark: "?"
        case .number(let n): "?\(n)"
        case .colon(let s): ":\(s)"
        case .at(let s): "@\(s)"
        case .tcl(let s, let suffix): "$\(s.map(\.value).joined(separator: "::"))\(suffix.map { "(\($0))" } ?? "")"
        }
    }
    
    func accept<V: ExprSyntaxVisitor>(visitor: inout V) -> V.ExprOutput {
        return visitor.visit(self)
    }
}
