//
//  QualifiedName.swift
//  Feather
//
//  Created by Wes Wickwire on 6/2/25.
//

/// A fully qualified name. This can be used for tables, indices or anything
/// that is `schema.name` based.
public struct QualifiedName: Hashable, Sendable, CustomStringConvertible {
    /// The non qualified name.
    public let name: Substring
    /// The schema it exists in if any.
    /// Tables like CTE's do not have a schema so
    /// it needs to be optional.
    public let schema: SchemaName?
    
    public init(name: Substring, schema: SchemaName?) {
        self.name = name
        self.schema = schema
    }
    
    @_disfavoredOverload
    public init(name: Substring, schema: Substring?) {
        self.name = name
        self.schema = schema.map(SchemaName.init) ?? nil
    }
    
    public var description: String {
        return if let schema {
            "\(schema).\(name)"
        } else {
            name.description
        }
    }
}
