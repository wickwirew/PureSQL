//
//  Columns.swift
//  Otter
//
//  Created by Wes Wickwire on 6/2/25.
//

import OrderedCollections

public typealias Columns = DuplicateDictionary<Substring, Column>

extension Columns {
    /// Initializes the columns with their default names that SQLite gives to them.
    init(withDefaultNames types: [Type]) {
        self = types.enumerated()
            .reduce(into: [:]) { c, v in
                let column = Column(type: v.element, isGenerated: false)
                c.append(column, for: "column\(v.offset + 1)")
            }
    }
}

public struct Column: Equatable, Sendable {
    public let type: Type
    public let isGenerated: Bool
    public let hasDefault: Bool
    
    public init(
        type: Type,
        hasDefault: Bool = false,
        isGenerated: Bool = false
    ) {
        self.type = type
        self.hasDefault = hasDefault
        self.isGenerated = isGenerated
    }
    
    public var isRequired: Bool {
        return !isGenerated && !hasDefault && !type.isOptional
    }
    
    public func mapType(_ transform: (Type) -> Type) -> Column {
        return Column(
            type: transform(type),
            isGenerated: isGenerated
        )
    }
}

extension Column: CustomStringConvertible {
    public var description: String {
        if isGenerated {
            return "\(type) generated"
        } else {
            return type.description
        }
    }
}
