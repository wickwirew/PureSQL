//
//  TypeScheme.swift
//  Otter
//
//  Created by Wes Wickwire on 3/3/25.
//

struct TypeScheme: CustomStringConvertible, Sendable {
    let typeVariables: [TypeVariable]
    let type: Type

    var description : String {
        return "∀\(typeVariables.map(\.description).joined(separator: ", ")).\(self.type)"
    }
}
