//
//  IdentifierSyntax.swift
//
//
//  Created by Wes Wickwire on 10/19/24.
//

public struct IdentifierSyntax: Sendable {
    private(set) public var value: Substring
    private(set) public var range: Range<String.Index>
    
    public init(value: Substring, range: Range<String.Index>) {
        self.value = value
        self.range = range
    }
}

extension IdentifierSyntax: Equatable {
    public static func ==(lhs: IdentifierSyntax, rhs: IdentifierSyntax) -> Bool {
        return lhs.value == rhs.value
    }
}

extension IdentifierSyntax: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(value)
    }
}

extension IdentifierSyntax: CustomStringConvertible {
    public var description: String {
        return value.description
    }
}

extension IdentifierSyntax: ExpressibleByStringLiteral {
    public init(stringLiteral value: String) {
        self.value = value[...]
        self.range = value.startIndex..<value.endIndex
    }
}

extension IdentifierSyntax {
    public mutating func append(_ identifier: IdentifierSyntax) {
        value += identifier.value
        range = range.lowerBound..<identifier.range.upperBound
    }
    
    public mutating func append(_ string: String, upperBound: String.Index) {
        value += string
        range = range.lowerBound..<upperBound
    }
}
