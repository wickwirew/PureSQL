//
//  AST.swift
//
//
//  Created by Wes Wickwire on 10/8/24.
//

import OrderedCollections

public struct Tyy: Equatable {
    public let affinity: Affinity?
    public let defined: Substring?
    
    public init(affinity: Affinity?, defined: Substring?) {
        self.affinity = affinity
        self.defined = defined
    }
    
    public static let int = Tyy(affinity: .integer, defined: nil)
    public static let integer = Tyy(affinity: .integer, defined: nil)
    public static let real = Tyy(affinity: .real, defined: nil)
    public static let text = Tyy(affinity: .text, defined: nil)
    public static let blob = Tyy(affinity: .blob, defined: nil)
    public static let any = Tyy(affinity: nil, defined: nil)
    
    public enum Affinity: Equatable {
        case text
        case numeric
        case integer
        case real
        case blob
    }
}

public enum TypeName: Equatable {
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

extension TypeName: CustomStringConvertible {
    public var description: String {
        switch self {
        case .int: "INT"
        case .integer: "INTEGER"
        case .tinyint: "TINYINT"
        case .smallint: "SMALLINT"
        case .mediumint: "MEDIUMINT"
        case .bigint: "BIGINT"
        case .unsignedBigInt: "UNSIGNED BIG INT"
        case .int2: "INT2"
        case .int8: "INT8"
        case .numeric: "NUMERIC"
        case .decimal(let a, let b): "DECIMAL(\(a), \(b))"
        case .boolean: "BOOLEAN"
        case .date: "DATE"
        case .datetime: "DATETIME"
        case .real: "REAL"
        case .double: "DOUBLE"
        case .doublePrecision: "DOUBLE PRECISION"
        case .float: "FLOAT"
        case .character(let a): "CHARACTER(\(a))"
        case .varchar(let a): "VARCHAR(\(a))"
        case .varyingCharacter(let a): "VARYING CHARACTER(\(a))"
        case .nchar(let a): "NCHAR(\(a))"
        case .nativeCharacter(let a): "NATIVE CHARACTER(\(a))"
        case .nvarchar(let a): "NVARCHAR(\(a))"
        case .text: "TEXT"
        case .clob: "CLOB"
        case .blob: "BLOB"
        }
    }
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
        case expr(Expression)
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
    case numeric(Numeric, isInt: Bool)
    case string(Substring)
    case blob(Substring)
    case null
    case `true`
    case `false`
    case currentTime
    case currentDate
    case currentTimestamp
}

extension Literal: ExpressibleByStringLiteral {
    public init(stringLiteral value: String) {
        self = .string(value[...])
    }
}

extension Literal: ExpressibleByIntegerLiteral {
    public init(integerLiteral value: Int) {
        self = .numeric(Numeric(value), isInt: true)
    }
}

extension Literal: ExpressibleByFloatLiteral {
    public init(floatLiteral value: Double) {
        self = .numeric(value, isInt: false)
    }
}

extension Literal: CustomStringConvertible {
    public var description: String {
        switch self {
        case .numeric(let numeric, _):
            return numeric.description
        case .string(let substring):
            return "'\(substring.description)'"
        case .blob(let substring):
            return substring.description
        case .null:
            return "NULL"
        case .true:
            return "TRUE"
        case .false:
            return "FALSE"
        case .currentTime:
            return "CURRENT_TIME"
        case .currentDate:
            return "CURRENT_DATE"
        case .currentTimestamp:
            return "CURRENT_TIMESTAMP"
        }
    }
}

/// https://www.sqlite.org/syntax/select-core.html
public enum SelectCore: Equatable {
    /// SELECT column FROM foo
    case select(Select)
    /// VALUES (foo, bar baz)
    case values([Expression])
    
    public struct Select: Equatable {
        public let distinct: Bool
        public let columns: [ResultColumn]
        public let from: From?
        public let `where`: Expression?
        public let groupBy: GroupBy?
        public let windows: [Window]
        
        public init(
            distinct: Bool = false,
            columns: [ResultColumn],
            from: From?,
            `where`: Expression? = nil,
            groupBy: GroupBy? = nil,
            windows: [Window] = []
        ) {
            self.distinct = distinct
            self.columns = columns
            self.from = from
            self.where = `where`
            self.groupBy = groupBy
            self.windows = windows
        }
    }
    
    public struct Window: Equatable {
        public let name: Substring
        public let window: WindowDefinition
        
        public init(
            name: Substring,
            window: WindowDefinition
        ) {
            self.name = name
            self.window = window
        }
    }
    
    public enum From: Equatable {
        case tableOrSubqueries([TableOrSubquery])
        case join(JoinClause)
        
        public init(table: Substring) {
            self = .join(JoinClause(table: table))
        }
    }
    
    public struct GroupBy: Equatable {
        public let expressions: [Expression]
        public let having: Expression?
        
        public enum Nulls: Equatable {
            case first
            case last
        }
        
        public init(
            expressions: [Expression],
            having: Expression?
        ) {
            self.expressions = expressions
            self.having = having
        }
    }
}

public struct SelectStmt: Equatable {
    public let cte: Indirect<CommonTableExpression>?
    public let cteRecursive: Bool
    public let selects: Indirect<Selects>
    public let orderBy: [OrderingTerm]
    public let limit: Limit?
    
    public enum Selects: Equatable {
        case single(SelectCore)
        indirect case compound(Selects, CompoundOperator, SelectCore)
    }
    
    public init(
        cte: CommonTableExpression?,
        cteRecursive: Bool,
        selects: Selects,
        orderBy: [OrderingTerm],
        limit: Limit?
    ) {
        self.cte = cte.map(Indirect.init)
        self.cteRecursive = cteRecursive
        self.selects = Indirect(selects)
        self.orderBy = orderBy
        self.limit = limit
    }
    
    public init(
        cte: CommonTableExpression? = nil,
        cteRecursive: Bool = false,
        select: SelectCore.Select,
        orderBy: [OrderingTerm] = [],
        limit: Limit? = nil
    ) {
        self.cte = cte.map(Indirect.init)
        self.cteRecursive = cteRecursive
        self.selects = Indirect(.single(.select(select)))
        self.orderBy = orderBy
        self.limit = limit
    }
    
    public struct Limit: Equatable {
        public let expr: Expression
        public let offset: Expression?
        
        public init(expr: Expression, offset: Expression?) {
            self.expr = expr
            self.offset = offset
        }
    }
}

public enum ResultColumn: Equatable {
    /// Note: This will represent even just a single column select
    case expr(Expression, as: Substring?)
    /// `*` or `table.*`
    case all(table: Substring?)
}

public struct OrderingTerm: Equatable {
    public let expr: Expression
    public let order: Order
    public let nulls: Nulls?
    
    public enum Nulls: Equatable {
        case first
        case last
    }
    
    public init(
        expr: Expression,
        order: Order,
        nulls: Nulls?
    ) {
        self.expr = expr
        self.order = order
        self.nulls = nulls
    }
}

public enum CompoundOperator: Equatable {
    case union
    case unionAll
    case intersect
    case except
}

public struct JoinClause: Equatable {
    public let tableOrSubquery: TableOrSubquery
    public let joins: [Join]
    
    public init(
        tableOrSubquery: TableOrSubquery,
        joins: [Join]
    ) {
        self.tableOrSubquery = tableOrSubquery
        self.joins = joins
    }
    
    public init(
        table: Substring,
        joins: [Join] = []
    ) {
        self.tableOrSubquery = TableOrSubquery(table: table)
        self.joins = joins
    }
    
    public struct Join: Equatable {
        public let op: JoinOperator
        public let tableOrSubquery: TableOrSubquery
        public let constraint: JoinConstraint
        
        public init(
            op: JoinOperator,
            tableOrSubquery: TableOrSubquery,
            constraint: JoinConstraint
        ) {
            self.op = op
            self.tableOrSubquery = tableOrSubquery
            self.constraint = constraint
        }
    }
}

public enum JoinOperator: Equatable {
    
//    case natural
//    case naturalLeft
//    case naturalLeftOuter
//    case naturalRight
//    case naturalFull
//    case naturalInner
//    case left
//    case leftOuter
//    case right
//    case full
//    case inner
    
    
    case comma
    case join
    case natural
    case left(natural: Bool = false, outer: Bool = false)
    case right(natural: Bool = false, outer: Bool = false)
    case full(natural: Bool = false, outer: Bool = false)
    case inner(natural: Bool = false)
    case cross
}

public enum JoinConstraint: Equatable {
    case on(Expression)
    case using([Substring])
    case none
}

public enum TableOrSubquery: Equatable {
    case table(Table)
    case tableFunction(schema: Substring?, table: Substring, args: [Expression], alias: Substring?)
    case subquery(SelectStmt)
    indirect case join(JoinClause)
    case subTableOrSubqueries([TableOrSubquery], alias: Substring?)
    
    public init(
        schema: Substring? = nil,
        table: Substring,
        alias: Substring? = nil,
        indexedBy: Substring? = nil
    ) {
        self = .table(TableOrSubquery.Table(
            schema: schema,
            name: table,
            alias: alias,
            indexedBy: indexedBy
        ))
    }
    
    public struct Table: Equatable {
        public let schema: Substring?
        public let name: Substring
        public let alias: Substring?
        public let indexedBy: Substring?
        
        public init(
            schema: Substring?,
            name: Substring,
            alias: Substring?,
            indexedBy: Substring?
        ) {
            self.schema = schema
            self.name = name
            self.alias = alias
            self.indexedBy = indexedBy
        }
    }
}

public struct WindowDefinition: Equatable {
    public init() {}
}

public struct CommonTableExpression: Equatable {
    public let table: Substring?
    public let columns: [Substring]
    public let materialized: Bool
    public let select: SelectStmt
    
    public init(
        table: Substring?,
        columns: [Substring],
        materialized: Bool = false,
        select: SelectStmt
    ) {
        self.table = table
        self.columns = columns
        self.materialized = materialized
        self.select = select
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
        case unique(IndexedColumn, ConfictClause)
        case check(Expression)
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
        case check(Expression)
        case `default`(Default)
        case collate(Substring)
        case foreignKey(ForeignKeyClause)
        case generated(Expression, GeneratedKind?)
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
    case expr(Expression)
}

public struct ColumnDef: Equatable {
    public var name: Substring
    public var type: TypeName
    public var constraints: [ColumnConstraint]
    
    public init(
        name: Substring,
        type: TypeName,
        constraints: [ColumnConstraint]
    ) {
        self.name = name
        self.type = type
        self.constraints = constraints
    }
    
    public enum Default: Equatable {
        case literal(Literal)
        case signedNumber(SignedNumber)
        case expr(Expression)
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


@dynamicMemberLookup
public final class Indirect<Wrapped> {
    public var value: Wrapped
    
    public init(_ value: Wrapped) {
        self.value = value
    }
    
    public subscript<T>(dynamicMember keyPath: KeyPath<Wrapped, T>) -> T {
        return value[keyPath: keyPath]
    }
}

extension Indirect: Equatable where Wrapped: Equatable {
    public static func == (lhs: Indirect<Wrapped>, rhs: Indirect<Wrapped>) -> Bool {
        lhs.value == rhs.value
    }
}

extension Indirect: CustomStringConvertible {
    public var description: String {
        return "\(value)"
    }
}
