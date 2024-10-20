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
    public var columns: OrderedDictionary<Substring, ColumnDef>
    public var constraints: [TableConstraint]
    public var options: TableOptions
    
    public init(
        name: TableName,
        isTemporary: Bool,
        columns: OrderedDictionary<Substring, ColumnDef>,
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

public struct ColumnSchema {
    public var name: Substring
    public var type: Ty
    public var constraints: [Constraints]
    
    public struct Constraints: OptionSet, Equatable {
        public let rawValue: UInt8
        
        public static let notNull = Constraints(rawValue: 1 << 0)
        public static let primaryKey = Constraints(rawValue: 1 << 1)
        
        public init(rawValue: UInt8) {
            self.rawValue = rawValue
        }
    }
}

public struct Query<Input, Output> {
    public let input: Input
    public let sql: String
    
    
}
