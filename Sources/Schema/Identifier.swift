//
//  Identifier.swift
//
//
//  Created by Wes Wickwire on 10/19/24.
//

public struct Identifier: Sendable {
    private(set) public var name: Substring
    private(set) public var range: Range<String.Index>
    
    public init(name: Substring, range: Range<String.Index>) {
        self.name = name
        self.range = range
    }
}

extension Identifier: Equatable {
    public static func ==(lhs: Identifier, rhs: Identifier) -> Bool {
        return lhs.name == rhs.name
    }
}

extension Identifier: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(name)
    }
}

extension Identifier: CustomStringConvertible {
    public var description: String {
        return name.description
    }
}

extension Identifier: ExpressibleByStringLiteral {
    public init(stringLiteral value: String) {
        self.name = value[...]
        self.range = value.startIndex..<value.endIndex
    }
}

extension Identifier {
    public mutating func append(_ identifier: Identifier) {
        name += identifier.name
        range = range.lowerBound..<identifier.range.upperBound
    }
    
    public mutating func append(_ string: String, upperBound: String.Index) {
        name += string
        range = range.lowerBound..<upperBound
    }
}
