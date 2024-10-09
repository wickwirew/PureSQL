//
//  AST.swift
//
//
//  Created by Wes Wickwire on 10/8/24.
//

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
    
    public init?(
        name: Substring,
        with l: Numeric? = nil,
        and r: Numeric? = nil
    ) {
        switch name.uppercased() {
        case "INT": self = .int
        case "INTEGER": self = .integer
        case "TINYINT": self = .tinyint
        case "SMALLINT": self = .smallint
        case "MEDIUMINT": self = .mediumint
        case "BIGINT": self = .bigint
        case "UNSIGNED BIG INT": self = .unsignedBigInt
        case "INT2": self = .int2
        case "INT8": self = .int8
        case "NUMERIC": self = .numeric
        case "DECIMAL": self = .decimal(Int(l ?? 0), Int(r ?? 0))
        case "BOOLEAN": self = .boolean
        case "DATE": self = .date
        case "DATETIME": self = .datetime
        case "REAL": self = .real
        case "DOUBLE": self = .double
        case "DOUBLE PRECISION": self = .doublePrecision
        case "FLOAT": self = .float
        case "CHARACTER": self = .character(Int(l ?? 0))
        case "VARCHAR": self = .varchar(Int(l ?? 0))
        case "VARYING CHARACTER": self = .varyingCharacter(Int(l ?? 0))
        case "NCHAR": self = .nchar(Int(l ?? 0))
        case "NATIVE CHARACTER": self = .nativeCharacter(Int(l ?? 0))
        case "NVARCHAR": self = .nvarchar(Int(l ?? 0))
        case "TEXT": self = .text
        case "CLOB": self = .clob
        case "BLOB": self = .blob
        default: return nil
        }
    }
}


public struct Expr: Equatable {
    // TODO
    public init() {}
}

public enum Stmt: Equatable {
    case createTable(CreateTableStmt)
}

public enum ConfictClause: Equatable {
    case rollback
    case abort
    case fail
    case ignore
    case replace
}

public struct PrimaryKeyConstraint: Equatable {
    public let columns: [Substring]
    public let confictClause: ConfictClause?
    public let autoincrement: Bool
    
    public init(
        columns: [Substring],
        confictClause: ConfictClause?,
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
    public let order: Order?
    
    public init(kind: Kind, collation: Substring?, order: Order?) {
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
    public let action: Action?
    
    public init(
        foreignTable: Substring,
        foreignColumns: [Substring],
        action: Action?
    ) {
        self.foreignTable = foreignTable
        self.foreignColumns = foreignColumns
        self.action = action
    }
    
    public enum Action: Equatable {
        case onDo(On, Do)
        indirect case match(Substring, Action)
        case deferrable(Deferrable)
        case notDeferrable(Deferrable)
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

//public struct TypeName: Equatable {
//    public let name: Substring
//    public let typeParams: (Numeric?, Numeric?)
//    
//    public init(name: Substring, typeParams: (Numeric?, Numeric?)) {
//        self.name = name
//        self.typeParams = typeParams
//    }
//    
//    public static func == (lhs: TypeName, rhs: TypeName) -> Bool {
//        lhs.name == rhs.name && lhs.typeParams == rhs.typeParams
//    }
//}

public struct CreateTableStmt: Equatable {
    public let name: Substring
    public let schemaName: Substring
    public let isTemporary: Bool
    public let onlyIfExists: Bool
    public let kind: Kind
    public let constraints: [TableConstraint]
    public let options: TableOptions
    
    public init(
        name: Substring,
        schemaName: Substring,
        isTemporary: Bool,
        onlyIfExists: Bool,
        kind: Kind,
        constraints: [TableConstraint],
        options: TableOptions
    ) {
        self.name = name
        self.schemaName = schemaName
        self.isTemporary = isTemporary
        self.onlyIfExists = onlyIfExists
        self.kind = kind
        self.constraints = constraints
        self.options = options
    }
    
    public enum Kind: Equatable {
        case select(SelectStmt)
        case columns([Substring: ColumnDef])
    }
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
        case unique(IndexedColumn, ConfictClause?)
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
        case primaryKey(order: Order?, ConfictClause?, autoincrement: Bool)
        case notNull(ConfictClause?)
        case unique(ConfictClause?)
        case check(Expr)
        case `default`(Default)
        case collate(Substring)
        case foreignKey(ForeignKeyClause)
        case generated(Expr, Generated?)
    }
    
    public enum Generated {
        case stored
        case virtual
    }
}

public enum Default: Equatable {
    case literal(Literal)
    case expr(Expr)
}

public struct ColumnDef: Equatable {
    public let name: Substring
    public let type: Ty
    public let constraints: [ColumnConstraint]
    
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
