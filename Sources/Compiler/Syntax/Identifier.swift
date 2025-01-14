//
//  Identifier.swift
//
//
//  Created by Wes Wickwire on 10/19/24.
//

struct Identifier: Sendable {
    private(set) var value: Substring
    private(set) var range: Range<String.Index>

    init(value: Substring, range: Range<String.Index>) {
        self.value = value
        self.range = range
    }
}

extension Identifier: Equatable {
    static func ==(lhs: Identifier, rhs: Identifier) -> Bool {
        return lhs.value == rhs.value
    }
}

extension Identifier: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(value)
    }
}

extension Identifier: CustomStringConvertible {
    var description: String {
        return value.description
    }
}

extension Identifier: ExpressibleByStringLiteral {
    init(stringLiteral value: String) {
        self.value = value[...]
        self.range = value.startIndex..<value.endIndex
    }
}

extension Identifier {
    mutating func append(_ identifier: Identifier) {
        value += identifier.value
        range = range.lowerBound..<identifier.range.upperBound
    }

    mutating func append(_ string: String, upperBound: String.Index) {
        value += string
        range = range.lowerBound..<upperBound
    }
}
