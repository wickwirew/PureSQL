//
//  Index.swift
//  Feather
//
//  Created by Wes Wickwire on 6/2/25.
//

/// An index created within the schema
public struct Index {
    /// The name given too the index
    public let name: QualifiedName
    /// The name of the table the index was created for.
    public let table: QualifiedName
}
