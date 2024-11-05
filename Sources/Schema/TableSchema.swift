//
//  TableSchema.swift
//
//
//  Created by Wes Wickwire on 10/10/24.
//

import Foundation
import OrderedCollections

public struct TableSchema {
    public var name: TableName
    public var isTemporary: Bool
    public var columns: OrderedDictionary<IdentifierSyntax, ColumnDef>
    public var constraints: [TableConstraint]
    public var options: TableOptions
    
    public init(
        name: TableName,
        isTemporary: Bool,
        columns: OrderedDictionary<IdentifierSyntax, ColumnDef>,
        constraints: [TableConstraint],
        options: TableOptions
    ) {
        self.name = name
        self.isTemporary = isTemporary
        self.columns = columns
        self.constraints = constraints
        self.options = options
    }
}

public struct Query<Input, Output> {
    public let input: Input
    public let sql: String
    
    
}
