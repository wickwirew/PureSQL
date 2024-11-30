//
//  IdentifierSyntax.swift
//
//
//  Created by Wes Wickwire on 10/19/24.
//

public struct Identifier: Sendable {
    private(set) public var value: Substring
    private(set) public var range: Range<String.Index>
    
    public init(value: Substring, range: Range<String.Index>) {
        self.value = value
        self.range = range
    }
}

extension Identifier: Equatable {
    public static func ==(lhs: Identifier, rhs: Identifier) -> Bool {
        return lhs.value == rhs.value
    }
}

extension Identifier: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(value)
    }
}

extension Identifier: CustomStringConvertible {
    public var description: String {
        return value.description
    }
}

extension Identifier: ExpressibleByStringLiteral {
    public init(stringLiteral value: String) {
        self.value = value[...]
        self.range = value.startIndex..<value.endIndex
    }
}

extension Identifier: ExpressibleByStringInterpolation {
    public init(stringInterpolation: DefaultStringInterpolation) {
        self.value = stringInterpolation.description[...]
        self.range = value.startIndex..<value.endIndex
    }
}

extension Identifier {
    public mutating func append(_ identifier: Identifier) {
        value += identifier.value
        range = range.lowerBound..<identifier.range.upperBound
    }
    
    public mutating func append(_ string: String, upperBound: String.Index) {
        value += string
        range = range.lowerBound..<upperBound
    }
}
