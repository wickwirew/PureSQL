//
//  Statements.swift
//
//
//  Created by Wes Wickwire on 10/8/24.
//

import OrderedCollections

protocol StmtVisitor {
    associatedtype StmtOutput
    mutating func visit(_ stmt: borrowing CreateTableStmt) -> StmtOutput
    mutating func visit(_ stmt: borrowing AlterTableStmt) -> StmtOutput
    mutating func visit(_ stmt: borrowing EmptyStmt) -> StmtOutput
    mutating func visit(_ stmt: borrowing SelectStmt) -> StmtOutput
    mutating func visit(_ stmt: borrowing InsertStmt) -> StmtOutput
}

protocol Stmt {
    func accept<V: StmtVisitor>(visitor: inout V) -> V.StmtOutput
}

struct CreateTableStmt: Stmt {
    let name: Identifier
    let schemaName: Identifier?
    let isTemporary: Bool
    let onlyIfExists: Bool
    let kind: Kind
    let constraints: [TableConstraint]
    let options: TableOptions

    enum Kind {
        case select(SelectStmt)
        case columns(OrderedDictionary<Identifier, ColumnDef>)
    }

    func accept<V>(visitor: inout V) -> V.StmtOutput where V : StmtVisitor {
        visitor.visit(self)
    }
}

struct AlterTableStmt: Stmt {
    let name: Identifier
    let schemaName: Identifier?
    let kind: Kind

    enum Kind {
        case rename(Identifier)
        case renameColumn(Identifier, Identifier)
        case addColumn(ColumnDef)
        case dropColumn(Identifier)
    }

    func accept<V>(visitor: inout V) -> V.StmtOutput where V : StmtVisitor {
        visitor.visit(self)
    }
}

/// Just an empty `;` statement. Silly but useful in the parser.
struct EmptyStmt: Equatable, Stmt {
    init() {}

    func accept<V>(visitor: inout V) -> V.StmtOutput where V : StmtVisitor {
        visitor.visit(self)
    }
}

struct TypeName: Equatable, CustomStringConvertible, Sendable {
    let name: Identifier
    let arg1: SignedNumber?
    let arg2: SignedNumber?

    var description: String {
        if let arg1, let arg2 {
            return "\(name)(\(arg1), \(arg2))"
        } else if let arg1 {
            return "\(name)(\(arg1))"
        } else {
            return name.description
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
    }

    struct GroupBy {
        let expressions: [Expression]
        let having: Expression?

        enum Nulls {
            case first
            case last
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

    struct Join {
        let op: JoinOperator
        let tableOrSubquery: TableOrSubquery
        let constraint: JoinConstraint
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

    struct Table {
        let schema: Identifier?
        let name: Identifier
        let alias: Identifier?
        let indexedBy: Identifier?
    }
}

// TODO: Implement windows
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
