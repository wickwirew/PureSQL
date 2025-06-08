//
//  TypeScheme.swift
//  Feather
//
//  Created by Wes Wickwire on 3/3/25.
//

struct TypeScheme: CustomStringConvertible, Sendable {
    let typeVariables: [TypeVariable]
    let type: Type
    
    init(
        typeVariables: [TypeVariable],
        type: Type
    ) {
        self.typeVariables = typeVariables
        self.type = type
    }
    
    init(_ type: Type) {
        self.typeVariables = []
        self.type = type
    }
    
    var description : String {
        return "∀\(typeVariables.map(\.description).joined(separator: ", ")).\(self.type)"
    }
}
