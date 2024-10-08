//
//  AST.swift
//
//
//  Created by Wes Wickwire on 10/8/24.
//


struct Expr {
    // TODO
}

enum ConfictClause {
    case rollback
    case abort
    case fail
    case ignore
    case replace
}

struct PrimaryKeyConstraint {
    let columns: [Substring]
    let confictClause: ConfictClause?
    let autoincrement: Bool
}

enum Order {
    case asc
    case desc
}

struct IndexedColumn {
    let kind: Kind
    let collation: Substring?
    let order: Order?
    
    enum Kind {
        case column(Substring)
        case expr(Expr)
    }
}

struct ForeignKeyClause {
    let foreignTable: Substring
    let foreignColumns: [Substring]
    
    enum Kind {
        case onDo(On, Do)
        indirect case match(Match)
        case deferrable(not: Bool, Deferrable)
    }
    
    enum On {
        case delete
        case update
    }
    
    enum Do {
        case setNull
        case setDefault
        case cascade
        case restrict
        case noAction
    }
    
    struct Match {
        let name: Substring
        let kind: Kind
    }
    
    enum Deferrable {
        case initiallyDeferred
        case initiallyImmediate
    }
}

typealias Numeric = Double
typealias SignedNumber = Double

enum Literal {
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

struct SelectStmt {
    // TODO
}

struct TypeName {
    let name: Substring
    let typeParams: (Numeric?, Numeric?)
}

struct CreateTableStmt {
    let name: Substring
    let schemaName: Substring
    let isTemporary: Bool
    let onlyIfExists: Bool
    let kind: [Kind]
    let constraints: [TableConstraint]
    let options: TableOptions
    
    enum Kind {
        case select(SelectStmt)
        case columns([ColumnDef])
    }
}

struct TableConstraint {
    let name: Substring?
    let kind: Kind
    
    enum Kind {
        case primaryKey([IndexedColumn], ConfictClause)
        case unique(IndexedColumn, ConfictClause?)
        case check(Expr)
        case foreignKey([Substring], ForeignKeyClause)
    }
}

struct ColumnConstraint {
    let name: Substring?
    let kind: Kind
    
    enum Kind {
        case primaryKey(ascending: Bool, ConfictClause?, autoincrement: Bool)
        case notNull(ConfictClause?)
        case unique(ConfictClause?)
        case check(Expr)
        case `default`(Numeric)
        case collate(Substring)
        case foreignKey(ForeignKeyClause)
        case generated(Expr, stored: Bool)
    }
}

struct ColumnDef {
    let name: Substring
    let typeName: TypeName
    let constraints: [ColumnConstraint]
    
    enum Default {
        case literal(Literal)
        case signedNumber(SignedNumber)
        case expr(Expr)
    }
}

struct TableOptions: OptionSet {
    let rawValue: UInt8
    
    static let withoutRowId = TableOptions(rawValue: 1 << 0)
    static let strict = TableOptions(rawValue: 1 << 1)
}
