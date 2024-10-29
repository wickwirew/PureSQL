//
//  AST.swift
//
//
//  Created by Wes Wickwire on 10/8/24.
//

import OrderedCollections

public struct TypeName: Equatable, CustomStringConvertible {
    public let name: Identifier
    public let args: Args?
    public let resolved: Resolved?
    
    public static let text = TypeName(name: "TEXT", args: nil, resolved: .text)
    public static let int = TypeName(name: "INT", args: nil, resolved: .int)
    public static let integer = TypeName(name: "INTEGER", args: nil, resolved: .integer)
    public static let real = TypeName(name: "REAL", args: nil, resolved: .real)
    public static let blob = TypeName(name: "BLOB", args: nil, resolved: .blob)
    public static let any = TypeName(name: "ANY", args: nil, resolved: .any)
    public static let bool = TypeName(name: "BOOL", args: nil, resolved: .int)
    
    public init(name: Identifier, args: Args?) {
        self.name = name
        self.args = args
        self.resolved = Resolved(name.description)
    }
    
    public init(name: Identifier, args: Args?, resolved: Resolved) {
        self.name = name
        self.args = args
        self.resolved = resolved
    }
    
    public enum Args: Equatable {
        case one(SignedNumber)
        case two(SignedNumber, SignedNumber)
    }
    
    public var isNumber: Bool {
        return self == .int
            || self == .integer
            || self == .real
    }
    
    /// SQLites data types are a bit funny. You can type in pretty much
    /// anything you want and it be valid SQL. These are just the types
    /// that SQLite will recognize and to be used for static analysis.
    public enum Resolved: Equatable {
        case text
        case int
        case integer
        case real
        case blob
        case any
        
        init?(_ name: String) {
            switch name.uppercased() {
            case "TEXT": self = .text
            case "INT": self = .int
            case "INTEGER": self = .integer
            case "REAL": self = .real
            case "BLOB": self = .blob
            case "ANY": self = .any
            default: return nil
            }
        }
    }

    public var description: String {
        switch self.args {
        case .none:
            return name.description
        case .one(let arg):
            return "\(name)(\(arg))"
        case .two(let arg1, let arg2):
            return "\(name)(\(arg1), \(arg2))"
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
    public let columns: [Identifier]
    public let confictClause: ConfictClause
    public let autoincrement: Bool
    
    public init(
        columns: [Identifier],
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
    public let collation: Identifier?
    public let order: Order
    
    public init(kind: Kind, collation: Identifier?, order: Order) {
        self.kind = kind
        self.collation = collation
        self.order = order
    }
    
    public enum Kind: Equatable {
        case column(Identifier)
        case expr(Expression)
    }
}

public struct ForeignKeyClause: Equatable {
    public let foreignTable: Identifier
    public let foreignColumns: [Identifier]
    public let actions: [Action]
    
    public init(
        foreignTable: Identifier,
        foreignColumns: [Identifier],
        actions: [Action]
    ) {
        self.foreignTable = foreignTable
        self.foreignColumns = foreignColumns
        self.actions = actions
    }
    
    public enum Action: Equatable {
        case onDo(On, Do)
        indirect case match(Identifier, [Action])
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
        public let name: Identifier
        public let window: WindowDefinition
        
        public init(
            name: Identifier,
            window: WindowDefinition
        ) {
            self.name = name
            self.window = window
        }
    }
    
    public enum From: Equatable {
        case tableOrSubqueries([TableOrSubquery])
        case join(JoinClause)
        
        public init(table: Identifier) {
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
    case expr(Expression, as: Identifier?)
    /// `*` or `table.*`
    case all(table: Identifier?)
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
        table: Identifier,
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
    case using([Identifier])
    case none
    
    public var on: Expression? {
        if case let .on(e) = self { return e }
        return nil
    }
}

public enum TableOrSubquery: Equatable {
    case table(Table)
    case tableFunction(schema: Identifier?, table: Identifier, args: [Expression], alias: Identifier?)
    case subquery(SelectStmt)
    indirect case join(JoinClause)
    case subTableOrSubqueries([TableOrSubquery], alias: Identifier?)
    
    public init(
        schema: Identifier? = nil,
        table: Identifier,
        alias: Identifier? = nil,
        indexedBy: Identifier? = nil
    ) {
        self = .table(TableOrSubquery.Table(
            schema: schema,
            name: table,
            alias: alias,
            indexedBy: indexedBy
        ))
    }
    
    public struct Table: Equatable {
        public let schema: Identifier?
        public let name: Identifier
        public let alias: Identifier?
        public let indexedBy: Identifier?
        
        public init(
            schema: Identifier?,
            name: Identifier,
            alias: Identifier?,
            indexedBy: Identifier?
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
    public let table: Identifier?
    public let columns: [Identifier]
    public let materialized: Bool
    public let select: SelectStmt
    
    public init(
        table: Identifier?,
        columns: [Identifier],
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
    public let name: Identifier?
    public let kind: Kind
    
    public init(name: Identifier?, kind: Kind) {
        self.name = name
        self.kind = kind
    }
    
    public enum Kind: Equatable {
        case primaryKey([IndexedColumn], ConfictClause)
        case unique(IndexedColumn, ConfictClause)
        case check(Expression)
        case foreignKey([Identifier], ForeignKeyClause)
    }
}

public struct ColumnConstraint: Equatable {
    public let name: Identifier?
    public let kind: Kind
    
    public init(name: Identifier?, kind: Kind) {
        self.name = name
        self.kind = kind
    }
    
    public enum Kind: Equatable {
        case primaryKey(order: Order, ConfictClause, autoincrement: Bool)
        case notNull(ConfictClause)
        case unique(ConfictClause)
        case check(Expression)
        case `default`(Expression)
        case collate(Identifier)
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

public struct ColumnDef: Equatable {
    public var name: Identifier
    public var type: TypeName
    public var constraints: [ColumnConstraint]
    
    public init(
        name: Identifier,
        type: TypeName,
        constraints: [ColumnConstraint]
    ) {
        self.name = name
        self.type = type
        self.constraints = constraints
    }
    
    public enum Default: Equatable {
        case literal(LiteralExpr)
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

public struct TableName: Hashable, CustomStringConvertible {
    public let schema: Schema
    public let name: Identifier
    
    public static let main: Identifier = "main"
    
    public enum Schema: Hashable {
        case main
        case other(Identifier)
    }
    
    public init(schema: Schema, name: Identifier) {
        self.schema = schema
        self.name = name
    }
    
    public init(schema: Identifier?, name: Identifier) {
        if let schema, schema == Self.main {
            self.schema = .other(schema)
        } else {
            self.schema = .main
        }
        self.name = name
    }
    
    public var description: String {
        switch schema {
        case .main:
            return name.description
        case .other(let schema):
            return "\(schema).\(name)"
        }
    }
    
    public func with(name: Identifier) -> TableName {
        return TableName(schema: schema, name: name)
    }
}
