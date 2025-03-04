//
//  TypeScheme.swift
//  Feather
//
//  Created by Wes Wickwire on 3/3/25.
//

struct TypeScheme: CustomStringConvertible, Sendable {
    let typeVariables: [TypeVariable]
    let type: Type
    let variadic: Bool
    
    init(
        typeVariables: [TypeVariable],
        type: Type,
        variadic: Bool = false
    ) {
        self.typeVariables = typeVariables
        self.type = type
        self.variadic = variadic
    }
    
    init(_ type: Type) {
        self.typeVariables = []
        self.type = type
        self.variadic = false
    }
    
    var description : String {
        return "∀\(typeVariables.map(\.description).joined(separator: ", ")).\(self.type)"
    }
}
