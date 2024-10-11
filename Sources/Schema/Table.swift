//
//  Table.swift
//  
//
//  Created by Wes Wickwire on 10/10/24.
//

import Foundation
import OrderedCollections

public struct Table {
    public var name: Substring
    public var schemaName: Substring?
    public var isTemporary: Bool
    public var columns: OrderedDictionary<Substring, ColumnDef>
    public var constraints: [TableConstraint]
    public var options: TableOptions
    
    public init(
        name: Substring,
        schemaName: Substring?,
        isTemporary: Bool,
        columns: OrderedDictionary<Substring, ColumnDef>,
        constraints: [TableConstraint],
        options: TableOptions
    ) {
        self.name = name
        self.schemaName = schemaName
        self.isTemporary = isTemporary
        self.columns = columns
        self.constraints = constraints
        self.options = options
    }
}
