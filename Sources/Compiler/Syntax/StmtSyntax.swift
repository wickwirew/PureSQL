//
//  StmtSyntax.swift
//
//
//  Created by Wes Wickwire on 10/8/24.
//

import OrderedCollections

protocol StmtSyntax: Syntax {
    func accept<V: StmtSyntaxVisitor>(visitor: inout V) -> V.StmtOutput
}

protocol StmtSyntaxVisitor {
    associatedtype StmtOutput
    mutating func visit(_ stmt: borrowing CreateTableStmtSyntax) -> StmtOutput
    mutating func visit(_ stmt: borrowing AlterTableStmtSyntax) -> StmtOutput
    mutating func visit(_ stmt: borrowing EmptyStmtSyntax) -> StmtOutput
    mutating func visit(_ stmt: borrowing SelectStmtSyntax) -> StmtOutput
    mutating func visit(_ stmt: borrowing InsertStmtSyntax) -> StmtOutput
    mutating func visit(_ stmt: borrowing UpdateStmtSyntax) -> StmtOutput
    mutating func visit(_ stmt: borrowing DeleteStmtSyntax) -> StmtOutput
    mutating func visit(_ stmt: borrowing QueryDefinitionStmtSyntax) -> StmtOutput
    mutating func visit(_ stmt: borrowing PragmaStmt) -> StmtOutput
}

struct CreateTableStmtSyntax: StmtSyntax {
    let name: IdentifierSyntax
    let schemaName: IdentifierSyntax?
    let isTemporary: Bool
    let onlyIfExists: Bool
    let kind: Kind
    let constraints: [TableConstraintSyntax]
    let options: TableOptionsSyntax
    let range: Range<String.Index>

    typealias Columns = OrderedDictionary<IdentifierSyntax, ColumnDefSyntax>
    
    enum Kind {
        case select(SelectStmtSyntax)
        case columns(Columns)
    }

    func accept<V>(visitor: inout V) -> V.StmtOutput where V : StmtSyntaxVisitor {
        visitor.visit(self)
    }
}

struct AlterTableStmtSyntax: StmtSyntax {
    let name: IdentifierSyntax
    let schemaName: IdentifierSyntax?
    let kind: Kind
    let range: Range<String.Index>

    enum Kind {
        case rename(IdentifierSyntax)
        case renameColumn(IdentifierSyntax, IdentifierSyntax)
        case addColumn(ColumnDefSyntax)
        case dropColumn(IdentifierSyntax)
    }

    func accept<V>(visitor: inout V) -> V.StmtOutput where V : StmtSyntaxVisitor {
        visitor.visit(self)
    }
}

struct QueryDefinitionStmtSyntax: StmtSyntax {
    let name: IdentifierSyntax
    let statement: any StmtSyntax
    let range: Range<String.Index>
    
    func accept<V>(visitor: inout V) -> V.StmtOutput where V : StmtSyntaxVisitor {
        return visitor.visit(self)
    }
}

/// Just an empty `;` statement. Silly but useful in the parser.
struct EmptyStmtSyntax: Equatable, StmtSyntax {
    let range: Range<String.Index>
    
    func accept<V>(visitor: inout V) -> V.StmtOutput where V : StmtSyntaxVisitor {
        visitor.visit(self)
    }
}

struct TypeNameSyntax: Syntax, Equatable, CustomStringConvertible, Sendable {
    let name: IdentifierSyntax
    let arg1: SignedNumberSyntax?
    let arg2: SignedNumberSyntax?
    let alias: IdentifierSyntax?
    let range: Range<Substring.Index>

    var description: String {
        let type = if let arg1, let arg2 {
            "\(name)(\(arg1), \(arg2))"
        } else if let arg1 {
            "\(name)(\(arg1))"
        } else {
            name.description
        }
        
        if let alias {
            return "\(type) AS \(alias)"
        } else {
            return type
        }
    }
}

enum ConfictClauseSyntax {
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

struct OrderSyntax: Syntax, CustomStringConvertible {
    let kind: Kind
    let range: Range<Substring.Index>
    
    enum Kind: String {
        case asc
        case desc
    }
    
    var description: String {
        return kind.rawValue
    }
}

struct IndexedColumnSyntax: Syntax {
    let expr: ExpressionSyntax
    let collation: IdentifierSyntax?
    let order: OrderSyntax?
    
    var range: Range<Substring.Index> {
        let upper = order?.range.upperBound ?? collation?.range.upperBound ?? expr.range.upperBound
        return expr.range.lowerBound..<upper
    }
    
    var columnName: IdentifierSyntax? {
        guard case let .column(column) = expr else { return nil }
        return column.column
    }
}

struct ForeignKeyClauseSyntax: Syntax {
    let foreignTable: IdentifierSyntax
    let foreignColumns: [IdentifierSyntax]
    let actions: [Action]
    let range: Range<Substring.Index>

    enum Action {
        case onDo(On, Do)
        indirect case match(IdentifierSyntax, [Action])
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

typealias NumericSyntax = Double
typealias SignedNumberSyntax = Double

/// https://www.sqlite.org/syntax/select-core.html
enum SelectCoreSyntax {
    /// SELECT column FROM foo
    case select(Select)
    /// VALUES (foo, bar baz)
    case values([[ExpressionSyntax]])

    struct Select {
        let distinct: Bool
        let columns: [ResultColumnSyntax]
        let from: FromSyntax?
        let `where`: ExpressionSyntax?
        let groupBy: GroupBy?
        let windows: [Window]

        init(
            distinct: Bool = false,
            columns: [ResultColumnSyntax],
            from: FromSyntax?,
            where: ExpressionSyntax? = nil,
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
        let name: IdentifierSyntax
        let window: WindowDefinitionSyntax
    }

    struct GroupBy {
        let expressions: [ExpressionSyntax]
        let having: ExpressionSyntax?

        enum Nulls {
            case first
            case last
        }
    }
}

struct SelectStmtSyntax: StmtSyntax {
    let cte: Indirect<CommonTableExpressionSyntax>?
    let cteRecursive: Bool
    let selects: Indirect<Selects>
    let orderBy: [OrderingTermSyntax]
    let limit: Limit?
    let range: Range<Substring.Index>

    enum Selects {
        case single(SelectCoreSyntax)
        indirect case compound(Selects, CompoundOperatorSyntax, SelectCoreSyntax)
    }

    struct Limit {
        let expr: ExpressionSyntax
        let offset: ExpressionSyntax?
    }

    func accept<V>(visitor: inout V) -> V.StmtOutput where V : StmtSyntaxVisitor {
        visitor.visit(self)
    }
}

struct DeleteStmtSyntax: StmtSyntax {
    let cte: CommonTableExpressionSyntax?
    let cteRecursive: Bool
    let table: QualifiedTableNameSyntax
    let whereExpr: ExpressionSyntax?
    let returningClause: ReturningClauseSyntax?
    let range: Range<Substring.Index>
    
    func accept<V>(visitor: inout V) -> V.StmtOutput where V : StmtSyntaxVisitor {
        return visitor.visit(self)
    }
}

enum ResultColumnSyntax {
    /// Note: This will represent even just a single column select
    case expr(ExpressionSyntax, as: IdentifierSyntax?)
    /// `*` or `table.*`
    case all(table: IdentifierSyntax?)
}

struct OrderingTermSyntax {
    let expr: ExpressionSyntax
    let order: OrderSyntax?
    let nulls: Nulls?

    enum Nulls {
        case first
        case last
    }
}

enum CompoundOperatorSyntax {
    case union
    case unionAll
    case intersect
    case except
}

struct JoinClauseSyntax {
    let tableOrSubquery: TableOrSubquerySyntax
    let joins: [Join]

    struct Join {
        let op: JoinOperatorSyntax
        let tableOrSubquery: TableOrSubquerySyntax
        let constraint: JoinConstraintSyntax
    }
}

enum JoinOperatorSyntax {
    case comma
    case join
    case natural
    case left(natural: Bool = false, outer: Bool = false)
    case right(natural: Bool = false, outer: Bool = false)
    case full(natural: Bool = false, outer: Bool = false)
    case inner(natural: Bool = false)
    case cross
}

enum JoinConstraintSyntax {
    case on(ExpressionSyntax)
    case using([IdentifierSyntax])
    case none

    var on: ExpressionSyntax? {
        if case let .on(e) = self { return e }
        return nil
    }
}

enum TableOrSubquerySyntax {
    case table(Table)
    case tableFunction(schema: IdentifierSyntax?, table: IdentifierSyntax, args: [ExpressionSyntax], alias: IdentifierSyntax?)
    case subquery(SelectStmtSyntax, alias: IdentifierSyntax?)
    indirect case join(JoinClauseSyntax)
    case subTableOrSubqueries([TableOrSubquerySyntax], alias: IdentifierSyntax?)

    struct Table {
        let schema: IdentifierSyntax?
        let name: IdentifierSyntax
        let alias: IdentifierSyntax?
        let indexedBy: IdentifierSyntax?
    }
}

// TODO: Implement windows
struct WindowDefinitionSyntax {
    init() {}
}

struct CommonTableExpressionSyntax {
    let table: IdentifierSyntax
    let columns: [IdentifierSyntax]
    let materialized: Bool
    let select: SelectStmtSyntax
    let range: Range<Substring.Index>
}

struct TableConstraintSyntax: Syntax {
    let name: IdentifierSyntax?
    let kind: Kind
    let range: Range<Substring.Index>

    enum Kind {
        case primaryKey([IndexedColumnSyntax], ConfictClauseSyntax)
        case unique(IndexedColumnSyntax, ConfictClauseSyntax)
        case check(ExpressionSyntax)
        case foreignKey([IdentifierSyntax], ForeignKeyClauseSyntax)
    }
}

struct ColumnConstraintSyntax: Syntax {
    let name: IdentifierSyntax?
    let kind: Kind
    let range: Range<Substring.Index>

    enum Kind {
        case primaryKey(order: OrderSyntax?, ConfictClauseSyntax, autoincrement: Bool)
        case notNull(ConfictClauseSyntax)
        case unique(ConfictClauseSyntax)
        case check(ExpressionSyntax)
        case `default`(ExpressionSyntax)
        case collate(IdentifierSyntax)
        case foreignKey(ForeignKeyClauseSyntax)
        case generated(ExpressionSyntax, GeneratedKind?)
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

struct ColumnDefSyntax: Syntax {
    var name: IdentifierSyntax
    var type: TypeNameSyntax
    var constraints: [ColumnConstraintSyntax]
    
    var range: Range<Substring.Index> {
        let upper = constraints.last?.range.upperBound ?? type.range.upperBound
        return name.range.lowerBound..<upper
    }
}

struct TableOptionsSyntax: OptionSet, Sendable, CustomStringConvertible {
    let rawValue: UInt8

    static let withoutRowId = TableOptionsSyntax(rawValue: 1 << 0)
    static let strict = TableOptionsSyntax(rawValue: 1 << 1)

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

struct TableNameSyntax: Syntax, Hashable, CustomStringConvertible {
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

    func with(name: IdentifierSyntax) -> TableNameSyntax {
        return TableNameSyntax(schema: schema, name: name)
    }
}

struct PragmaStmt: StmtSyntax {
    let schema: IdentifierSyntax?
    let name: IdentifierSyntax
    let value: ExprSyntax?
    let isFunctionCall: Bool
    let range: Range<Substring.Index>
    
    func accept<V>(visitor: inout V) -> V.StmtOutput where V : StmtSyntaxVisitor {
        return visitor.visit(self)
    }
}
