//
//  Table.swift
//  
//
//  Created by Wes Wickwire on 10/10/24.
//

import Foundation

public struct Table {
    public private(set) var name: Substring
    public private(set) var schemaName: Substring?
    public private(set) var isTemporary: Bool
    public private(set) var columns: [Substring: ColumnDef]
    public private(set) var constraints: [TableConstraint]
    public private(set) var options: TableOptions
    
    public init(
        name: Substring,
        schemaName: Substring?,
        isTemporary: Bool,
        columns: [Substring: ColumnDef],
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
