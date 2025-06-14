//
//  IdentifierSyntax.swift
//
//
//  Created by Wes Wickwire on 10/19/24.
//

struct IdentifierSyntax: Sendable, Syntax {
    let id: SyntaxId
    private(set) var value: Substring
    private(set) var location: SourceLocation
}

extension IdentifierSyntax: Equatable {
    static func ==(lhs: IdentifierSyntax, rhs: IdentifierSyntax) -> Bool {
        return lhs.value == rhs.value
    }
}

extension IdentifierSyntax: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(value)
    }
}

extension IdentifierSyntax: CustomStringConvertible {
    var description: String {
        return value.description
    }
}

extension IdentifierSyntax {
    mutating func append(_ identifier: IdentifierSyntax) {
        value += identifier.value
        location = location.with(upperbound: identifier.location.range.upperBound)
    }

    mutating func append(_ string: String, upperBound: String.Index) {
        value += string
        location = location.with(upperbound: upperBound)
    }
}
