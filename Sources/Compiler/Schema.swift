//
//  AST.swift
//
//
//  Created by Wes Wickwire on 10/8/24.
//

import OrderedCollections

struct TypeName: Equatable, CustomStringConvertible, Sendable {
    let name: IdentifierSyntax
    let args: Args?
    let resolved: Resolved?
    
    static let text = TypeName(name: "TEXT", args: nil, resolved: .text)
    static let int = TypeName(name: "INT", args: nil, resolved: .int)
    static let integer = TypeName(name: "INTEGER", args: nil, resolved: .integer)
    static let real = TypeName(name: "REAL", args: nil, resolved: .real)
    static let blob = TypeName(name: "BLOB", args: nil, resolved: .blob)
    static let any = TypeName(name: "ANY", args: nil, resolved: .any)
    static let bool = TypeName(name: "BOOL", args: nil, resolved: .int)
    
    init(name: IdentifierSyntax, args: Args?) {
        self.name = name
        self.args = args
        self.resolved = Resolved(name.description)
    }
    
    init(name: IdentifierSyntax, args: Args?, resolved: Resolved) {
        self.name = name
        self.args = args
        self.resolved = resolved
    }
    
    enum Args: Equatable, Sendable {
        case one(SignedNumber)
        case two(SignedNumber, SignedNumber)
    }
    
    var isNumber: Bool {
        return self == .int
            || self == .integer
            || self == .real
    }
    
    /// SQLites data types are a bit funny. You can type in pretty much
    /// anything you want and it be valid SQL. These are just the types
    /// that SQLite will recognize and to be used for static analysis.
    enum Resolved: Equatable, Sendable {
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

    var description: String {
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

enum ConfictClause: Equatable {
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

struct PrimaryKeyConstraint: Equatable {
    let columns: [IdentifierSyntax]
    let confictClause: ConfictClause
    let autoincrement: Bool
    
    init(
        columns: [IdentifierSyntax],
        confictClause: ConfictClause,
        autoincrement: Bool
    ) {
        self.columns = columns
        self.confictClause = confictClause
        self.autoincrement = autoincrement
    }
}

enum Order: Equatable {
    case asc
    case desc
}

struct IndexedColumn: Equatable {
    let kind: Kind
    let collation: IdentifierSyntax?
    let order: Order
    
    init(kind: Kind, collation: IdentifierSyntax?, order: Order) {
        self.kind = kind
        self.collation = collation
        self.order = order
    }
    
    enum Kind: Equatable {
        case column(IdentifierSyntax)
        case expr(Expression)
    }
}

struct ForeignKeyClause: Equatable {
    let foreignTable: IdentifierSyntax
    let foreignColumns: [IdentifierSyntax]
    let actions: [Action]
    
    init(
        foreignTable: IdentifierSyntax,
        foreignColumns: [IdentifierSyntax],
        actions: [Action]
    ) {
        self.foreignTable = foreignTable
        self.foreignColumns = foreignColumns
        self.actions = actions
    }
    
    enum Action: Equatable {
        case onDo(On, Do)
        indirect case match(IdentifierSyntax, [Action])
        case deferrable(Deferrable?)
        case notDeferrable(Deferrable?)
    }
    
    enum On: Equatable {
        case delete
        case update
    }
    
    enum Do: Equatable {
        case setNull
        case setDefault
        case cascade
        case restrict
        case noAction
    }
    
    enum Deferrable: Equatable {
        case initiallyDeferred
        case initiallyImmediate
    }
}

typealias Numeric = Double
typealias SignedNumber = Double

/// https://www.sqlite.org/syntax/select-core.html
enum SelectCore: Equatable {
    /// SELECT column FROM foo
    case select(Select)
    /// VALUES (foo, bar baz)
    case values([Expression])
    
    struct Select: Equatable {
        let distinct: Bool
        let columns: [ResultColumn]
        let from: From?
        let `where`: Expression?
        let groupBy: GroupBy?
        let windows: [Window]
        
        init(
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
    
    struct Window: Equatable {
        let name: IdentifierSyntax
        let window: WindowDefinition
        
        init(
            name: IdentifierSyntax,
            window: WindowDefinition
        ) {
            self.name = name
            self.window = window
        }
    }
    
    enum From: Equatable {
        case tableOrSubqueries([TableOrSubquery])
        case join(JoinClause)
        
        init(table: IdentifierSyntax) {
            self = .join(JoinClause(table: table))
        }
    }
    
    struct GroupBy: Equatable {
        let expressions: [Expression]
        let having: Expression?
        
        enum Nulls: Equatable {
            case first
            case last
        }
        
        init(
            expressions: [Expression],
            having: Expression?
        ) {
            self.expressions = expressions
            self.having = having
        }
    }
}

struct SelectStmt: Statement, Equatable {
    let cte: Indirect<CommonTableExpression>?
    let cteRecursive: Bool
    let selects: Indirect<Selects>
    let orderBy: [OrderingTerm]
    let limit: Limit?
    
    enum Selects: Equatable {
        case single(SelectCore)
        indirect case compound(Selects, CompoundOperator, SelectCore)
    }
    
    init(
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
    
    init(
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
    
    struct Limit: Equatable {
        let expr: Expression
        let offset: Expression?
        
        init(expr: Expression, offset: Expression?) {
            self.expr = expr
            self.offset = offset
        }
    }
    
    func accept<V>(visitor: inout V) -> V.Output where V : StatementVisitor {
        visitor.visit(self)
    }
}

enum ResultColumn: Equatable {
    /// Note: This will represent even just a single column select
    case expr(Expression, as: IdentifierSyntax?)
    /// `*` or `table.*`
    case all(table: IdentifierSyntax?)
}

struct OrderingTerm: Equatable {
    let expr: Expression
    let order: Order
    let nulls: Nulls?
    
    enum Nulls: Equatable {
        case first
        case last
    }
    
    init(
        expr: Expression,
        order: Order,
        nulls: Nulls?
    ) {
        self.expr = expr
        self.order = order
        self.nulls = nulls
    }
}

enum CompoundOperator: Equatable {
    case union
    case unionAll
    case intersect
    case except
}

struct JoinClause: Equatable {
    let tableOrSubquery: TableOrSubquery
    let joins: [Join]
    
    init(
        tableOrSubquery: TableOrSubquery,
        joins: [Join]
    ) {
        self.tableOrSubquery = tableOrSubquery
        self.joins = joins
    }
    
    init(
        table: IdentifierSyntax,
        joins: [Join] = []
    ) {
        self.tableOrSubquery = TableOrSubquery(table: table)
        self.joins = joins
    }
    
    struct Join: Equatable {
        let op: JoinOperator
        let tableOrSubquery: TableOrSubquery
        let constraint: JoinConstraint
        
        init(
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

enum JoinOperator: Equatable {
    case comma
    case join
    case natural
    case left(natural: Bool = false, outer: Bool = false)
    case right(natural: Bool = false, outer: Bool = false)
    case full(natural: Bool = false, outer: Bool = false)
    case inner(natural: Bool = false)
    case cross
}

enum JoinConstraint: Equatable {
    case on(Expression)
    case using([IdentifierSyntax])
    case none
    
    var on: Expression? {
        if case let .on(e) = self { return e }
        return nil
    }
}

enum TableOrSubquery: Equatable {
    case table(Table)
    case tableFunction(schema: IdentifierSyntax?, table: IdentifierSyntax, args: [Expression], alias: IdentifierSyntax?)
    case subquery(SelectStmt, alias: IdentifierSyntax?)
    indirect case join(JoinClause)
    case subTableOrSubqueries([TableOrSubquery], alias: IdentifierSyntax?)
    
    init(
        schema: IdentifierSyntax? = nil,
        table: IdentifierSyntax,
        alias: IdentifierSyntax? = nil,
        indexedBy: IdentifierSyntax? = nil
    ) {
        self = .table(TableOrSubquery.Table(
            schema: schema,
            name: table,
            alias: alias,
            indexedBy: indexedBy
        ))
    }
    
    struct Table: Equatable {
        let schema: IdentifierSyntax?
        let name: IdentifierSyntax
        let alias: IdentifierSyntax?
        let indexedBy: IdentifierSyntax?
        
        init(
            schema: IdentifierSyntax?,
            name: IdentifierSyntax,
            alias: IdentifierSyntax?,
            indexedBy: IdentifierSyntax?
        ) {
            self.schema = schema
            self.name = name
            self.alias = alias
            self.indexedBy = indexedBy
        }
    }
}

struct WindowDefinition: Equatable {
    init() {}
}

struct CommonTableExpression: Equatable {
    let table: IdentifierSyntax?
    let columns: [IdentifierSyntax]
    let materialized: Bool
    let select: SelectStmt
    
    init(
        table: IdentifierSyntax?,
        columns: [IdentifierSyntax],
        materialized: Bool = false,
        select: SelectStmt
    ) {
        self.table = table
        self.columns = columns
        self.materialized = materialized
        self.select = select
    }
}

struct TableConstraint: Equatable {
    let name: IdentifierSyntax?
    let kind: Kind
    
    init(name: IdentifierSyntax?, kind: Kind) {
        self.name = name
        self.kind = kind
    }
    
    enum Kind: Equatable {
        case primaryKey([IndexedColumn], ConfictClause)
        case unique(IndexedColumn, ConfictClause)
        case check(Expression)
        case foreignKey([IdentifierSyntax], ForeignKeyClause)
    }
}

struct ColumnConstraint: Equatable {
    let name: IdentifierSyntax?
    let kind: Kind
    
    init(name: IdentifierSyntax?, kind: Kind) {
        self.name = name
        self.kind = kind
    }
    
    enum Kind: Equatable {
        case primaryKey(order: Order, ConfictClause, autoincrement: Bool)
        case notNull(ConfictClause)
        case unique(ConfictClause)
        case check(Expression)
        case `default`(Expression)
        case collate(IdentifierSyntax)
        case foreignKey(ForeignKeyClause)
        case generated(Expression, GeneratedKind?)
    }
    
    enum GeneratedKind {
        case stored
        case virtual
    }
    
    var isPkConstraint: Bool {
        switch kind {
        case .primaryKey: return true
        default: return false
        }
    }
    
    var isNotNullConstraint: Bool {
        switch kind {
        case .notNull: return true
        default: return false
        }
    }
}

struct ColumnDef: Equatable {
    var name: IdentifierSyntax
    var type: TypeName
    var constraints: [ColumnConstraint]
    
    init(
        name: IdentifierSyntax,
        type: TypeName,
        constraints: [ColumnConstraint]
    ) {
        self.name = name
        self.type = type
        self.constraints = constraints
    }
    
    enum Default: Equatable {
        case literal(LiteralExpr)
        case signedNumber(SignedNumber)
        case expr(Expression)
    }
}

struct TableOptions: OptionSet, Sendable, CustomStringConvertible {
    let rawValue: UInt8
    
    static let withoutRowId = TableOptions(rawValue: 1 << 0)
    static let strict = TableOptions(rawValue: 1 << 1)
    
    init(rawValue: UInt8) {
        self.rawValue = rawValue
    }
    
    var description: String {
        guard rawValue > 0 else { return "[]" }
        var opts: [String] = []
        if self.contains(.withoutRowId) { opts.append("WITHOUT ROWID") }
        if self.contains(.strict) { opts.append("STRICT") }
        return "[\(opts.joined(separator: ", "))]"
    }
}


@dynamicMemberLookup
final class Indirect<Wrapped> {
    var value: Wrapped
    
    init(_ value: Wrapped) {
        self.value = value
    }
    
    subscript<T>(dynamicMember keyPath: KeyPath<Wrapped, T>) -> T {
        return value[keyPath: keyPath]
    }
}

extension Indirect: Equatable where Wrapped: Equatable {
    static func == (lhs: Indirect<Wrapped>, rhs: Indirect<Wrapped>) -> Bool {
        lhs.value == rhs.value
    }
}

extension Indirect: CustomStringConvertible {
    var description: String {
        return "\(value)"
    }
}

struct TableName: Hashable, CustomStringConvertible {
    let schema: Schema
    let name: IdentifierSyntax
    
    static let main: IdentifierSyntax = "main"
    
    enum Schema: Hashable {
        case main
        case other(IdentifierSyntax)
    }
    
    init(schema: Schema, name: IdentifierSyntax) {
        self.schema = schema
        self.name = name
    }
    
    init(schema: IdentifierSyntax?, name: IdentifierSyntax) {
        if let schema, schema == Self.main {
            self.schema = .other(schema)
        } else {
            self.schema = .main
        }
        self.name = name
    }
    
    var description: String {
        switch schema {
        case .main:
            return name.description
        case .other(let schema):
            return "\(schema).\(name)"
        }
    }
    
    func with(name: IdentifierSyntax) -> TableName {
        return TableName(schema: schema, name: name)
    }
}

struct InsertStmt: Equatable {
    let cte: Indirect<CommonTableExpression>?
    let cteRecursive: Bool
    let action: Action
    let tableName: TableName
    let tableAlias: IdentifierSyntax
    let values: Values
    let returningClause: ReturningClause
    
    enum Values: Equatable {
        case select(SelectStmt, UpsertClause?)
        case defaultValues
    }
    
    enum Action: Equatable {
        case replace
        case insert(Or?)
    }
    
    enum Or: Equatable {
        case abort
        case fail
        case ignore
        case replace
        case rollback
    }
    
    init(
        cte: CommonTableExpression?,
        cteRecursive: Bool,
        action: Action,
        tableName: TableName,
        tableAlias: IdentifierSyntax,
        values: Values,
        returningClause: ReturningClause
    ) {
        self.cte = cte.map(Indirect.init)
        self.cteRecursive = cteRecursive
        self.action = action
        self.tableName = tableName
        self.tableAlias = tableAlias
        self.values = values
        self.returningClause = returningClause
    }
}

struct ReturningClause: Equatable {
    let values: [Value]
    
    init(values: [Value]) {
        self.values = values
    }
    
    struct Value: Equatable {
        let expr: Expression
        let alias: IdentifierSyntax?
        
        init(expr: Expression, alias: IdentifierSyntax?) {
            self.expr = expr
            self.alias = alias
        }
    }
}

struct UpsertClause: Equatable {
    let confictTarget: Expression?
    let doAction: Do
    
    init(confictTarget: Expression?, doAction: Do) {
        self.confictTarget = confictTarget
        self.doAction = doAction
    }
    
    struct ConflictTarget: Equatable {
        let columns: [IndexedColumn]
        let condition: Expression?
    }
    
    enum Do: Equatable {
        case nothing
        case updateSet(sets: [SetAction], where: Expression?)
    }
    
    struct SetAction: Equatable {
        let column: Column
        let expr: Expression
        
        init(column: Column, expr: Expression) {
            self.column = column
            self.expr = expr
        }
    }
    
    enum Column: Equatable {
        case single(Substring)
        case list([Substring])
    }
}

