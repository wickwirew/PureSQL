//
//  IdentifierSyntax.swift
//
//
//  Created by Wes Wickwire on 10/19/24.
//

struct IdentifierSyntax: Sendable {
    private(set) var value: Substring
    private(set) var range: SourceLocation

    init(value: Substring, range: SourceLocation) {
        self.value = value
        self.range = range
    }
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

//extension IdentifierSyntax: ExpressibleByStringLiteral {
//    init(stringLiteral value: String) {
//        self.value = value[...]
//        self.range = value.startIndex..<value.endIndex
//    }
//}

extension IdentifierSyntax {
    mutating func append(_ identifier: IdentifierSyntax) {
        value += identifier.value
        range = range.with(upperbound: identifier.range.range.upperBound)
    }

    mutating func append(_ string: String, upperBound: String.Index) {
        value += string
        range = range.with(upperbound: upperBound)
    }
}
