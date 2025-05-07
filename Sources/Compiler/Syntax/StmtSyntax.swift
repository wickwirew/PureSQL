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
    mutating func visit(_ stmt: borrowing DropTableStmtSyntax) -> StmtOutput
    mutating func visit(_ stmt: borrowing DeleteStmtSyntax) -> StmtOutput
    mutating func visit(_ stmt: borrowing QueryDefinitionStmtSyntax) -> StmtOutput
    mutating func visit(_ stmt: borrowing PragmaStmt) -> StmtOutput
    mutating func visit(_ stmt: borrowing CreateIndexStmtSyntax) -> StmtOutput
    mutating func visit(_ stmt: borrowing DropIndexStmtSyntax) -> StmtOutput
    mutating func visit(_ stmt: borrowing ReindexStmtSyntax) -> StmtOutput
    mutating func visit(_ stmt: borrowing CreateViewStmtSyntax) -> StmtOutput
    mutating func visit(_ stmt: borrowing CreateVirtualTableStmtSyntax) -> StmtOutput
}

struct CreateTableStmtSyntax: StmtSyntax {
    let id: SyntaxId
    let name: IdentifierSyntax
    let schemaName: IdentifierSyntax?
    let isTemporary: Bool
    let onlyIfExists: Bool
    let kind: Kind
    let constraints: [TableConstraintSyntax]
    let options: TableOptionsSyntax
    let location: SourceLocation

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
    let id: SyntaxId
    let name: IdentifierSyntax
    let schemaName: IdentifierSyntax?
    let kind: Kind
    let location: SourceLocation

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

struct InsertStmtSyntax: StmtSyntax, Syntax {
    let id: SyntaxId
    let cte: CommonTableExpressionSyntax?
    let cteRecursive: Bool
    let action: Action
    let tableName: TableNameSyntax
    let tableAlias: AliasSyntax?
    let columns: [IdentifierSyntax]?
    let values: Values? // if nil, default values
    let returningClause: ReturningClauseSyntax?
    let location: SourceLocation

    struct Values: Syntax {
        let id: SyntaxId
        let select: SelectStmtSyntax
        let upsertClause: UpsertClauseSyntax?
        
        var location: SourceLocation {
            let lower = select.location
            let upper = upsertClause?.location ?? select.location
            return lower.spanning(upper)
        }
    }

    struct Action: Syntax {
        let id: SyntaxId
        let kind: Kind
        let location: SourceLocation
        
        enum Kind {
            case replace
            case insert(OrSyntax?)
        }
    }

    func accept<V>(visitor: inout V) -> V.StmtOutput where V : StmtSyntaxVisitor {
        visitor.visit(self)
    }
}

struct QueryDefinitionStmtSyntax: StmtSyntax {
    let id: SyntaxId
    let name: IdentifierSyntax
    let input: IdentifierSyntax?
    let output: IdentifierSyntax?
    let statement: any StmtSyntax
    let location: SourceLocation
    
    func accept<V>(visitor: inout V) -> V.StmtOutput where V : StmtSyntaxVisitor {
        return visitor.visit(self)
    }
}

/// Just an empty `;` statement. Silly but useful in the parser.
struct EmptyStmtSyntax: Equatable, StmtSyntax {
    let id: SyntaxId
    let location: SourceLocation
    
    func accept<V>(visitor: inout V) -> V.StmtOutput where V : StmtSyntaxVisitor {
        visitor.visit(self)
    }
}

struct TypeNameSyntax: Syntax, CustomStringConvertible, Sendable {
    let id: SyntaxId
    let name: IdentifierSyntax
    let arg1: SignedNumberSyntax?
    let arg2: SignedNumberSyntax?
    let alias: AliasSyntax?
    let location: SourceLocation

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

struct OrSyntax: Syntax, CustomStringConvertible {
    let id: SyntaxId
    let kind: Kind
    let location: SourceLocation
    
    enum Kind: String {
        case abort
        case fail
        case ignore
        case replace
        case rollback
    }
    
    var description: String {
        return kind.rawValue
    }
}

struct ReturningClauseSyntax: Syntax {
    let id: SyntaxId
    let values: [Value]
    let location: SourceLocation

    enum Value {
        case expr(expr: ExpressionSyntax, alias: AliasSyntax?)
        case all
    }
}

struct UpsertClauseSyntax: Syntax {
    let id: SyntaxId
    let confictTarget: ConflictTarget?
    let doAction: Do
    let location: SourceLocation

    struct ConflictTarget {
        let columns: [IndexedColumnSyntax]
        let condition: ExpressionSyntax?
    }

    enum Do {
        case nothing
        case updateSet(sets: [SetActionSyntax], where: ExpressionSyntax?)
    }
}

struct SetActionSyntax: Syntax {
    let id: SyntaxId
    let column: Column
    let expr: ExpressionSyntax
    
    var location: SourceLocation {
        return column.location.spanning(expr.location)
    }

    enum Column {
        case single(IdentifierSyntax)
        case list([IdentifierSyntax])
        
        var location: SourceLocation {
            switch self {
            case .single(let i): return i.location
            case .list(let l):
                guard let lower = l.first?.location,
                      let upper = l.last?.location else {
                    return .empty
                }
                
                return lower.spanning(upper)
            }
        }
    }
}

struct UpdateStmtSyntax: StmtSyntax {
    let id: SyntaxId
    let cte: CommonTableExpressionSyntax?
    let cteRecursive: Bool
    let or: OrSyntax?
    let tableName: QualifiedTableNameSyntax
    let sets: [SetActionSyntax]
    let from: FromSyntax?
    let whereExpr: ExpressionSyntax?
    let returningClause: ReturningClauseSyntax?
    let location: SourceLocation
    
    func accept<V>(visitor: inout V) -> V.StmtOutput where V : StmtSyntaxVisitor {
        return visitor.visit(self)
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
    let id: SyntaxId
    let kind: Kind
    let location: SourceLocation
    
    enum Kind: String {
        case asc
        case desc
    }
    
    var description: String {
        return kind.rawValue
    }
}

struct AliasSyntax: Syntax, CustomStringConvertible {
    let id: SyntaxId
    let identifier: IdentifierSyntax
    let location: SourceLocation
    
    var description: String {
        return identifier.description
    }
}

struct IndexedColumnSyntax: Syntax {
    let id: SyntaxId
    let expr: ExpressionSyntax
    let collation: IdentifierSyntax?
    let order: OrderSyntax?
    
    var location: SourceLocation {
        let upper = order?.location ?? collation?.location ?? expr.location
        return expr.location.spanning(upper)
    }
    
    var columnName: IdentifierSyntax? {
        guard case let .column(column) = expr else { return nil }
        return column.column
    }
}

struct ForeignKeyClauseSyntax: Syntax {
    let id: SyntaxId
    let foreignTable: IdentifierSyntax
    let foreignColumns: [IdentifierSyntax]
    let actions: [Action]
    let location: SourceLocation

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
    let id: SyntaxId
    let cte: Indirect<CommonTableExpressionSyntax>?
    let cteRecursive: Bool
    let selects: Indirect<Selects>
    let orderBy: [OrderingTermSyntax]
    let limit: Limit?
    let location: SourceLocation

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
    let id: SyntaxId
    let cte: CommonTableExpressionSyntax?
    let cteRecursive: Bool
    let table: QualifiedTableNameSyntax
    let whereExpr: ExpressionSyntax?
    let returningClause: ReturningClauseSyntax?
    let location: SourceLocation
    
    func accept<V>(visitor: inout V) -> V.StmtOutput where V : StmtSyntaxVisitor {
        return visitor.visit(self)
    }
}

struct ResultColumnSyntax: Syntax {
    let id: SyntaxId
    let kind: Kind
    let location: SourceLocation
    
    enum Kind {
        /// Note: This will represent even just a single column select
        case expr(ExpressionSyntax, as: AliasSyntax?)
        /// `*` or `table.*`
        case all(table: IdentifierSyntax?)
    }
}

struct OrderingTermSyntax: Syntax {
    let id: SyntaxId
    let expr: ExpressionSyntax
    let order: OrderSyntax?
    let nulls: Nulls?
    let location: SourceLocation

    enum Nulls {
        case first
        case last
    }
}

struct CompoundOperatorSyntax: Syntax {
    let id: SyntaxId
    let kind: Kind
    let location: SourceLocation
    
    enum Kind {
        case union
        case unionAll
        case intersect
        case except
    }
}

struct JoinClauseSyntax: Syntax {
    let id: SyntaxId
    let tableOrSubquery: TableOrSubquerySyntax
    let joins: [Join]
    let location: SourceLocation

    struct Join {
        let op: JoinOperatorSyntax
        let tableOrSubquery: TableOrSubquerySyntax
        let constraint: JoinConstraintSyntax
    }
}

struct JoinOperatorSyntax: Syntax {
    let id: SyntaxId
    let kind: Kind
    let location: SourceLocation
    
    enum Kind {
        case comma
        case join
        case natural
        case left(natural: Bool = false, outer: Bool = false)
        case right(natural: Bool = false, outer: Bool = false)
        case full(natural: Bool = false, outer: Bool = false)
        case inner(natural: Bool = false)
        case cross
    }
}

struct JoinConstraintSyntax: Syntax {
    let id: SyntaxId
    let kind: Kind
    let location: SourceLocation
    
    enum Kind {
        case on(ExpressionSyntax)
        case using([IdentifierSyntax])
        case none

        var on: ExpressionSyntax? {
            if case let .on(e) = self { return e }
            return nil
        }
    }
}

struct TableOrSubquerySyntax: Syntax {
    let id: SyntaxId
    let kind: Kind
    let location: SourceLocation
    
    enum Kind {
        case table(Table)
        case tableFunction(schema: IdentifierSyntax?, table: IdentifierSyntax, args: [ExpressionSyntax], alias: AliasSyntax?)
        case subquery(SelectStmtSyntax, alias: AliasSyntax?)
        indirect case join(JoinClauseSyntax)
        case subTableOrSubqueries([TableOrSubquerySyntax], alias: AliasSyntax?)
    }

    struct Table {
        let schema: IdentifierSyntax?
        let name: IdentifierSyntax
        let alias: AliasSyntax?
        let indexedBy: IdentifierSyntax?
    }
}

// TODO: Implement windows
struct WindowDefinitionSyntax: Syntax {
    let id: SyntaxId
    let location: SourceLocation
}

struct CommonTableExpressionSyntax: Syntax {
    let id: SyntaxId
    let table: IdentifierSyntax
    let columns: [IdentifierSyntax]
    let materialized: Bool
    let select: SelectStmtSyntax
    let location: SourceLocation
}

struct TableConstraintSyntax: Syntax {
    let id: SyntaxId
    let name: IdentifierSyntax?
    let kind: Kind
    let location: SourceLocation

    enum Kind {
        case primaryKey([IndexedColumnSyntax], ConfictClauseSyntax)
        case unique(IndexedColumnSyntax, ConfictClauseSyntax)
        case check(ExpressionSyntax)
        case foreignKey([IdentifierSyntax], ForeignKeyClauseSyntax)
    }
}

struct ColumnConstraintSyntax: Syntax {
    let id: SyntaxId
    let name: IdentifierSyntax?
    let kind: Kind
    let location: SourceLocation

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
    let id: SyntaxId
    var name: IdentifierSyntax
    var type: TypeNameSyntax
    var constraints: [ColumnConstraintSyntax]
    
    var location: SourceLocation {
        let upper = constraints.last?.location ?? type.location
        return name.location.spanning(upper)
    }
}

struct TableOptionsSyntax: Syntax, Sendable, CustomStringConvertible {
    let id: SyntaxId
    let kind: Kind
    let location: SourceLocation

    struct Kind: OptionSet {
        let rawValue: UInt8
        
        init(rawValue: UInt8) {
            self.rawValue = rawValue
        }
        
        static let withoutRowId = Kind(rawValue: 1 << 0)
        static let strict = Kind(rawValue: 1 << 1)
    }

    var description: String {
        guard kind.rawValue > 0 else { return "[]" }
        var opts: [String] = []
        if kind.contains(.withoutRowId) { opts.append("WITHOUT ROWID") }
        if kind.contains(.strict) { opts.append("STRICT") }
        return "[\(opts.joined(separator: ", "))]"
    }
}

struct TableNameSyntax: Syntax, Hashable, CustomStringConvertible {
    let id: SyntaxId
    let schema: Schema
    let name: IdentifierSyntax

    enum Schema: Hashable {
        case main
        case other(IdentifierSyntax)
    }

    var description: String {
        switch schema {
        case .main:
            return name.description
        case let .other(schema):
            return "\(schema).\(name)"
        }
    }

    var location: SourceLocation {
        return switch schema {
        case .main: name.location
        case let .other(schema): schema.location.spanning(name.location)
        }
    }
}

struct PragmaStmt: StmtSyntax {
    let id: SyntaxId
    let schema: IdentifierSyntax?
    let name: IdentifierSyntax
    let value: ExprSyntax?
    let isFunctionCall: Bool
    let location: SourceLocation
    
    func accept<V>(visitor: inout V) -> V.StmtOutput where V : StmtSyntaxVisitor {
        return visitor.visit(self)
    }
}

struct DropTableStmtSyntax: StmtSyntax {
    let id: SyntaxId
    let ifExists: Bool
    let tableName: TableNameSyntax
    let location: SourceLocation
    
    func accept<V>(visitor: inout V) -> V.StmtOutput where V : StmtSyntaxVisitor {
        return visitor.visit(self)
    }
}

struct CreateIndexStmtSyntax: StmtSyntax {
    let id: SyntaxId
    let unique: Bool
    let ifNotExists: Bool
    let schemaName: IdentifierSyntax?
    let name: IdentifierSyntax
    let table: IdentifierSyntax
    let indexedColumns: [IndexedColumnSyntax]
    let whereExpr: ExprSyntax?
    let location: SourceLocation
    
    func accept<V>(visitor: inout V) -> V.StmtOutput where V : StmtSyntaxVisitor {
        return visitor.visit(self)
    }
}

struct DropIndexStmtSyntax: StmtSyntax {
    let id: SyntaxId
    let ifExists: Bool
    let schemaName: IdentifierSyntax?
    let name: IdentifierSyntax
    let location: SourceLocation
    
    func accept<V>(visitor: inout V) -> V.StmtOutput where V : StmtSyntaxVisitor {
        return visitor.visit(self)
    }
}

struct ReindexStmtSyntax: StmtSyntax {
    let id: SyntaxId
    let schemaName: IdentifierSyntax?
    // Note: This can be the collation, index or table name
    let name: IdentifierSyntax?
    let location: SourceLocation
    
    func accept<V>(visitor: inout V) -> V.StmtOutput where V : StmtSyntaxVisitor {
        return visitor.visit(self)
    }
}

struct CreateViewStmtSyntax: StmtSyntax {
    let id: SyntaxId
    let temp: Bool
    let ifNotExists: Bool
    let schemaName: IdentifierSyntax?
    let name: IdentifierSyntax
    let columnNames: [IdentifierSyntax]
    let select: SelectStmtSyntax
    let location: SourceLocation
    
    func accept<V>(visitor: inout V) -> V.StmtOutput where V : StmtSyntaxVisitor {
        return visitor.visit(self)
    }
}

struct CreateVirtualTableStmtSyntax: StmtSyntax {
    let id: SyntaxId
    let ifNotExists: Bool
    let tableName: TableNameSyntax
    let module: Module
    let moduleName: IdentifierSyntax
    let arguments: [ModuleArgument]
    let location: SourceLocation
    
    enum Module {
        case fts5
        case unknown
    }
    
    enum ModuleArgument {
        case fts5Column(
            name: IdentifierSyntax,
            typeName: TypeNameSyntax?,
            notNull: SourceLocation?,
            unindexed: Bool
        )
        case fts5Option(name: IdentifierSyntax, value: ExprSyntax)
        case unknown
    }
    
    func accept<V>(visitor: inout V) -> V.StmtOutput where V : StmtSyntaxVisitor {
        return visitor.visit(self)
    }
}

struct QualifiedTableNameSyntax: Syntax {
    let id: SyntaxId
    let tableName: TableNameSyntax
    let alias: AliasSyntax?
    let indexed: Indexed?
    let location: SourceLocation

    enum Indexed {
        case not
        case by(IdentifierSyntax)
    }
}
