//
//  CompoundOperatorSyntax.swift
//  Feather
//
//  Created by Wes Wickwire on 5/7/25.
//

struct CompoundOperatorSyntax: Syntax {
    let id: SyntaxId
    let kind: Kind
    let location: SourceLocation
    
    enum Kind: CustomStringConvertible {
        case union
        case unionAll
        case intersect
        case except
        
        var description: String {
            switch self {
            case .union: "UNION"
            case .unionAll: "UNION ALL"
            case .intersect: "INTERSECT"
            case .except: "EXCEPT"
            }
        }
    }
}
