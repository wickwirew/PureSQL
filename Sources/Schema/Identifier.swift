//
//  Identifier.swift
//
//
//  Created by Wes Wickwire on 10/19/24.
//

public struct Identifier {
    public let name: Substring
    public let caseSensitive: Bool
    
    public init(_ name: Substring, caseSensitive: Bool = true) {
        self.name = name
        self.caseSensitive = caseSensitive
    }
}

extension Identifier: Equatable {
    public static func ==(lhs: Identifier, rhs: Identifier) -> Bool {
        if lhs.caseSensitive && rhs.caseSensitive {
            return lhs.name == rhs.name
        } else {
            return lhs.name.compare(rhs.name, options: .caseInsensitive) == .orderedSame
        }
    }
}

extension Identifier: Hashable {
    public func hash(into hasher: inout Hasher) {
        if caseSensitive {
            hasher.combine(name)
        } else {
            hasher.combine(name.uppercased())
        }
    }
}

extension Identifier: ExpressibleByStringLiteral {
    public init(stringLiteral value: String) {
        self.init(value[...])
    }
}
