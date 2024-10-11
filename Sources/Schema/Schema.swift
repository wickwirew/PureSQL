//
//  AST.swift
//
//
//  Created by Wes Wickwire on 10/8/24.
//

import OrderedCollections

public enum Ty: Equatable {
    case int
    case integer
    case tinyint
    case smallint
    case mediumint
    case bigint
    case unsignedBigInt
    case int2
    case int8
    case numeric
    case decimal(Int, Int)
    case boolean
    case date
    case datetime
    case real
    case double
    case doublePrecision
    case float
    case character(Int)
    case varchar(Int)
    case varyingCharacter(Int)
    case nchar(Int)
    case nativeCharacter(Int)
    case nvarchar(Int)
    case text
    case clob
    case blob
}

//public indirect enum Expr: Equatable {
//    case literal(Literal)
//    case bindParameter(Substring)
//    
//}

public struct Expr: Equatable {
    public init() {}
}

public enum Stmt: Equatable {
    case createTable(CreateTableStatement)
}

public enum ConfictClause: Equatable {
    case rollback
    case abort
    case fail
    case ignore
    case replace
    // Note: Normally would rather make `ConflictClause` `nil` in this
    // case but the clause according to sqlites documentation no clause
    // is still a part of the clause.
    // https://www.sqlite.org/syntax/conflict-clause.html
    case none
}

public struct PrimaryKeyConstraint: Equatable {
    public let columns: [Substring]
    public let confictClause: ConfictClause
    public let autoincrement: Bool
    
    public init(
        columns: [Substring],
        confictClause: ConfictClause,
        autoincrement: Bool
    ) {
        self.columns = columns
        self.confictClause = confictClause
        self.autoincrement = autoincrement
    }
}

public enum Order: Equatable {
    case asc
    case desc
}

public struct IndexedColumn: Equatable {
    public let kind: Kind
    public let collation: Substring?
    public let order: Order
    
    public init(kind: Kind, collation: Substring?, order: Order) {
        self.kind = kind
        self.collation = collation
        self.order = order
    }
    
    public enum Kind: Equatable {
        case column(Substring)
        case expr(Expr)
    }
}

public struct ForeignKeyClause: Equatable {
    public let foreignTable: Substring
    public let foreignColumns: [Substring]
    public let actions: [Action]
    
    public init(
        foreignTable: Substring,
        foreignColumns: [Substring],
        actions: [Action]
    ) {
        self.foreignTable = foreignTable
        self.foreignColumns = foreignColumns
        self.actions = actions
    }
    
    public enum Action: Equatable {
        case onDo(On, Do)
        indirect case match(Substring, [Action])
        case deferrable(Deferrable?)
        case notDeferrable(Deferrable?)
    }
    
    public enum On: Equatable {
        case delete
        case update
    }
    
    public enum Do: Equatable {
        case setNull
        case setDefault
        case cascade
        case restrict
        case noAction
    }
    
    public enum Deferrable: Equatable {
        case initiallyDeferred
        case initiallyImmediate
    }
}

public typealias Numeric = Double
public typealias SignedNumber = Double

public enum Literal: Equatable {
    case numeric(Numeric)
    case string(Substring)
    case blob(Substring)
    case null
    case `true`
    case `false`
    case currentTime
    case currentDate
    case currentTimestamp
}

public struct SelectStmt: Equatable {
    // TODO
    public init() {}
}

public struct TableConstraint: Equatable {
    public let name: Substring?
    public let kind: Kind
    
    public init(name: Substring?, kind: Kind) {
        self.name = name
        self.kind = kind
    }
    
    public enum Kind: Equatable {
        case primaryKey([IndexedColumn], ConfictClause)
        case unique(IndexedColumn, ConfictClause)
        case check(Expr)
        case foreignKey([Substring], ForeignKeyClause)
    }
}

public struct ColumnConstraint: Equatable {
    public let name: Substring?
    public let kind: Kind
    
    public init(name: Substring?, kind: Kind) {
        self.name = name
        self.kind = kind
    }
    
    public enum Kind: Equatable {
        case primaryKey(order: Order, ConfictClause, autoincrement: Bool)
        case notNull(ConfictClause)
        case unique(ConfictClause)
        case check(Expr)
        case `default`(Default)
        case collate(Substring)
        case foreignKey(ForeignKeyClause)
        case generated(Expr, GeneratedKind?)
    }
    
    public enum GeneratedKind {
        case stored
        case virtual
    }
    
    public var isPkConstraint: Bool {
        switch kind {
        case .primaryKey: return true
        default: return false
        }
    }
    
    public var isNotNullConstraint: Bool {
        switch kind {
        case .notNull: return true
        default: return false
        }
    }
}

public enum Default: Equatable {
    case literal(Literal)
    case expr(Expr)
}

public struct ColumnDef: Equatable {
    public var name: Substring
    public var type: Ty
    public var constraints: [ColumnConstraint]
    
    public init(
        name: Substring,
        type: Ty,
        constraints: [ColumnConstraint]
    ) {
        self.name = name
        self.type = type
        self.constraints = constraints
    }
    
    public enum Default: Equatable {
        case literal(Literal)
        case signedNumber(SignedNumber)
        case expr(Expr)
    }
}

public struct TableOptions: OptionSet {
    public let rawValue: UInt8
    
    public init(rawValue: UInt8) {
        self.rawValue = rawValue
    }
    
    public static let withoutRowId = TableOptions(rawValue: 1 << 0)
    public static let strict = TableOptions(rawValue: 1 << 1)
}


