//
//  Trigger.swift
//  Otter
//
//  Created by Wes Wickwire on 6/2/25.
//

/// A trigger to be run on certain SQL operations
public struct Trigger {
    /// The name of the trigger
    public let name: QualifiedName
    /// The table the trigger is watching
    public let targetTable: QualifiedName
    /// Any table accessed in the `BEGIN/END`
    public let usedTables: Set<Substring>
}
