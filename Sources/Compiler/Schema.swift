//
//  Schema.swift
//
//
//  Created by Wes Wickwire on 10/8/24.
//

import OrderedCollections

public typealias Schema = OrderedDictionary<Substring, CompiledTable>

// TODO: An ordered dictionary may not be the best representation of the
// TODO: columns. Since this is used even in selects, the user could
// TODO: technically do `SELECT foo, foo FROM bar;` which have the same
// TODO: name which the ordered dictionary wouldnt catch. Or just error?
public typealias Columns = OrderedDictionary<Substring, Ty>

struct TypeName: Equatable, CustomStringConvertible, Sendable {
    let name: Identifier
    let args: Args?
    
    static let text = TypeName(name: "TEXT", args: nil)
    static let int = TypeName(name: "INT", args: nil)
    static let integer = TypeName(name: "INTEGER", args: nil)
    static let real = TypeName(name: "REAL", args: nil)
    static let blob = TypeName(name: "BLOB", args: nil)
    static let any = TypeName(name: "ANY", args: nil)
    static let bool = TypeName(name: "BOOL", args: nil)
    
    init(name: Identifier, args: Args?) {
        self.name = name
        self.args = args
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
        case let .one(arg):
            return "\(name)(\(arg))"
        case let .two(arg1, arg2):
            return "\(name)(\(arg1), \(arg2))"
        }
    }
}

enum ConfictClause {
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

struct PrimaryKeyConstraint {
    let columns: [Identifier]
    let confictClause: ConfictClause
    let autoincrement: Bool
    
    init(
        columns: [Identifier],
        confictClause: ConfictClause,
        autoincrement: Bool
    ) {
        self.columns = columns
        self.confictClause = confictClause
        self.autoincrement = autoincrement
    }
}

enum Order {
    case asc
    case desc
}

struct IndexedColumn {
    let expr: Expression
    let collation: Identifier?
    let order: Order
}

struct ForeignKeyClause {
    let foreignTable: Identifier
    let foreignColumns: [Identifier]
    let actions: [Action]
    
    init(
        foreignTable: Identifier,
        foreignColumns: [Identifier],
        actions: [Action]
    ) {
        self.foreignTable = foreignTable
        self.foreignColumns = foreignColumns
        self.actions = actions
    }
    
    enum Action {
        case onDo(On, Do)
        indirect case match(Identifier, [Action])
        case deferrable(Deferrable?)
        case notDeferrable(Deferrable?)
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
    
    enum Deferrable {
        case initiallyDeferred
        case initiallyImmediate
    }
}

typealias Numeric = Double
typealias SignedNumber = Double

/// https://www.sqlite.org/syntax/select-core.html
enum SelectCore {
    /// SELECT column FROM foo
    case select(Select)
    /// VALUES (foo, bar baz)
    case values([Expression])
    
    struct Select {
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
            where: Expression? = nil,
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
    
    struct Window {
        let name: Identifier
        let window: WindowDefinition
        
        init(
            name: Identifier,
            window: WindowDefinition
        ) {
            self.name = name
            self.window = window
        }
    }
    
    struct GroupBy {
        let expressions: [Expression]
        let having: Expression?
        
        enum Nulls {
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

struct SelectStmt: Stmt {
    let cte: Indirect<CommonTableExpression>?
    let cteRecursive: Bool
    let selects: Indirect<Selects>
    let orderBy: [OrderingTerm]
    let limit: Limit?
    let range: Range<Substring.Index>
    
    enum Selects {
        case single(SelectCore)
        indirect case compound(Selects, CompoundOperator, SelectCore)
    }
    
    struct Limit {
        let expr: Expression
        let offset: Expression?
        
        init(expr: Expression, offset: Expression?) {
            self.expr = expr
            self.offset = offset
        }
    }
    
    func accept<V>(visitor: inout V) -> V.StmtOutput where V : StmtVisitor {
        visitor.visit(self)
    }
}

enum ResultColumn {
    /// Note: This will represent even just a single column select
    case expr(Expression, as: Identifier?)
    /// `*` or `table.*`
    case all(table: Identifier?)
}

struct OrderingTerm {
    let expr: Expression
    let order: Order
    let nulls: Nulls?
    
    enum Nulls {
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

enum CompoundOperator {
    case union
    case unionAll
    case intersect
    case except
}

struct JoinClause {
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
        table: Identifier,
        joins: [Join] = []
    ) {
        self.tableOrSubquery = TableOrSubquery(table: table)
        self.joins = joins
    }
    
    struct Join {
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

enum JoinOperator {
    case comma
    case join
    case natural
    case left(natural: Bool = false, outer: Bool = false)
    case right(natural: Bool = false, outer: Bool = false)
    case full(natural: Bool = false, outer: Bool = false)
    case inner(natural: Bool = false)
    case cross
}

enum JoinConstraint {
    case on(Expression)
    case using([Identifier])
    case none
    
    var on: Expression? {
        if case let .on(e) = self { return e }
        return nil
    }
}

enum TableOrSubquery {
    case table(Table)
    case tableFunction(schema: Identifier?, table: Identifier, args: [Expression], alias: Identifier?)
    case subquery(SelectStmt, alias: Identifier?)
    indirect case join(JoinClause)
    case subTableOrSubqueries([TableOrSubquery], alias: Identifier?)
    
    init(
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
    
    struct Table {
        let schema: Identifier?
        let name: Identifier
        let alias: Identifier?
        let indexedBy: Identifier?
        
        init(
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

struct WindowDefinition {
    init() {}
}

struct CommonTableExpression {
    let table: Identifier
    let columns: [Identifier]
    let materialized: Bool
    let select: SelectStmt
    let range: Range<Substring.Index>
}

struct TableConstraint {
    let name: Identifier?
    let kind: Kind
    
    init(name: Identifier?, kind: Kind) {
        self.name = name
        self.kind = kind
    }
    
    enum Kind {
        case primaryKey([IndexedColumn], ConfictClause)
        case unique(IndexedColumn, ConfictClause)
        case check(Expression)
        case foreignKey([Identifier], ForeignKeyClause)
    }
}

struct ColumnConstraint {
    let name: Identifier?
    let kind: Kind
    
    init(name: Identifier?, kind: Kind) {
        self.name = name
        self.kind = kind
    }
    
    enum Kind {
        case primaryKey(order: Order, ConfictClause, autoincrement: Bool)
        case notNull(ConfictClause)
        case unique(ConfictClause)
        case check(Expression)
        case `default`(Expression)
        case collate(Identifier)
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

struct ColumnDef {
    var name: Identifier
    var type: TypeName
    var constraints: [ColumnConstraint]
    
    init(
        name: Identifier,
        type: TypeName,
        constraints: [ColumnConstraint]
    ) {
        self.name = name
        self.type = type
        self.constraints = constraints
    }
    
    enum Default {
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
    let name: Identifier
    
    static let main: Identifier = "main"
    
    enum Schema: Hashable {
        case main
        case other(Identifier)
    }
    
    init(schema: Schema, name: Identifier) {
        self.schema = schema
        self.name = name
    }
    
    init(schema: Identifier?, name: Identifier) {
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
        case let .other(schema):
            return "\(schema).\(name)"
        }
    }
    
    var range: Range<Substring.Index> {
        return switch schema {
        case .main: name.range
        case let .other(schema): schema.range.lowerBound..<name.range.upperBound
        }
    }
    
    func with(name: Identifier) -> TableName {
        return TableName(schema: schema, name: name)
    }
}
