//
//  CardinalityInferrer.swift
//  Feather
//
//  Created by Wes Wickwire on 2/16/25.
//

/// The amount of elements in the result set.
public enum Cardinality: String {
    case single
    case many
}

/// Infers the amount of items returned in a query.
/// This allows the generation to be smart and set the
/// return type to an Array only if needed.
struct CardinalityInferrer {
    let env: Environment
    
    mutating func cardinality<S: StmtSyntax>(for syntax: borrowing S) -> Cardinality {
        return syntax.accept(visitor: &self)
    }
    
    /// Returns the cardinality based off how a statement was fitlered.
    /// If it is filtered down to a single PK then it will return a single result.
    private mutating func cadinalityForFilter(
        _ expr: any ExprSyntax,
        for table: Table
    ) -> Cardinality {
        let filteredPrimaryKeys = expr.accept(visitor: &self)
        let didFilterByPrimaryKey = !table.primaryKey.contains{ !filteredPrimaryKeys.contains($0) }
        return didFilterByPrimaryKey ? .single : .many
    }
}

/// Returns `true` if the query/statement will only return one value.
extension CardinalityInferrer: StmtSyntaxVisitor {
    mutating func visit(_ stmt: CreateTableStmtSyntax) -> Cardinality { .many }
    
    mutating func visit(_ stmt: AlterTableStmtSyntax) -> Cardinality { .many }
    
    mutating func visit(_ stmt: EmptyStmtSyntax) -> Cardinality { .many }
    
    mutating func visit(_ stmt: PragmaStmtSyntax) -> Cardinality { .many }
    
    mutating func visit(_ stmt: DropTableStmtSyntax) -> Cardinality { .many }
    
    mutating func visit(_ stmt: UpdateStmtSyntax) -> Cardinality {
        // No filtering, update is to full table
        guard let whereExpr = stmt.whereExpr else { return .many }
        
        guard let table = env.resolve(
            table: stmt.tableName.tableName.name.value,
            schema: stmt.tableName.tableName.schema?.value
        ).value else {
            // Upstream will have emitted diag
            return .many
        }
        
        return cadinalityForFilter(whereExpr, for: table)
    }
    
    mutating func visit(_ stmt: SelectStmtSyntax) -> Cardinality {
        // See if there is a LIMIT 1 since this will always return a single result regardless
        // of what happens in the query.
        if let literal = stmt.limit?.expr as? LiteralExprSyntax, case let .numeric(i, _) = literal.kind, i == 1 {
            return .single
        }
        
        // A compound select since its bringing in multiple tables we could never know whether
        // a single result could be returned, and it is unlikely to do so.
        guard case let .single(selectCore) = stmt.selects.value else {
            return .many
        }
        
        switch selectCore {
        case .select(let select):
            // If its not filtered down with a `WHERE` it will always return more
            guard let filter = select.where else { return .many }
            
            if case let .join(join) = select.from {
                // If there are joins just return that it returns many rows.
                // In the future we could see if the joins are all a 1:1 and maybe
                // so some better inference but this will do for now. Adding a
                // `LIMIT 1` to the query will get them the result they want if
                // it is inferred as a list.
                guard join.joins.isEmpty else { return .many }
                
                // If its not against a table we cannot infer it.
                guard case let .table(table) = join.tableOrSubquery.kind else { return .many }
                
                // If we cannot find the table something upstream will have already emitted
                // diagnositic so just exit
                guard let t = env.resolve(
                    table: table.name.value,
                    schema: table.schema?.value
                ).value else { return .many }
                
                // If they had filtering on all primary keys we can assume a single
                // result will be returned.
                return cadinalityForFilter(filter, for: t)
            }
        case .values(let values):
            // VALUES (1, 2), (3, 4)
            if values.count > 1 {
                return .many
            }
        }

        return .many
    }
    
    mutating func visit(_ stmt: InsertStmtSyntax) -> Cardinality {
        // If no value, `DEFAULT VALUES` was used, which is one row.
        guard let values = stmt.values else { return .single }
        return values.select.accept(visitor: &self)
    }
    
    mutating func visit(_ stmt: DeleteStmtSyntax) -> Cardinality {
        guard let filter = stmt.whereExpr else { return .many }
        
        guard let table = env.resolve(
            table: stmt.table.tableName.name.value,
            schema: stmt.table.tableName.schema?.value
        ).value else {
            // Upstream will have emitted diag
            return .many
        }
        
        return cadinalityForFilter(filter, for: table)
    }
    
    mutating func visit(_ stmt: QueryDefinitionStmtSyntax) -> Cardinality {
        return stmt.statement.accept(visitor: &self)
    }
    
    mutating func visit(_ stmt: CreateIndexStmtSyntax) -> Cardinality { .many }
    
    mutating func visit(_ stmt: DropIndexStmtSyntax) -> Cardinality { .many }
    
    mutating func visit(_ stmt: ReindexStmtSyntax) -> Cardinality { .many }
    
    mutating func visit(_ stmt: CreateViewStmtSyntax) -> Cardinality { .many }
    
    mutating func visit(_ stmt: DropViewStmtSyntax) -> Cardinality { .many }
    
    mutating func visit(_ stmt: CreateVirtualTableStmtSyntax) -> Cardinality { .many }
    
    mutating func visit(_ stmt: CreateTriggerStmtSyntax) -> Cardinality { .many }
    
    mutating func visit(_ stmt: DropTriggerStmtSyntax) -> Cardinality { .many }
    
    mutating func visit(_ stmt: BeginStmtSyntax) -> Cardinality { .many }
    
    mutating func visit(_ stmt: CommitStmtSyntax) -> Cardinality { .many }
    
    mutating func visit(_ stmt: RollbackStmtSyntax) -> Cardinality { .many }
    
    mutating func visit(_ stmt: SavepointStmtSyntax) -> Cardinality { .many }
    
    mutating func visit(_ stmt: ReleaseStmtSyntax) -> Cardinality { .many }
}

/// We need to look for a `primaryKey = value`. This can get complicated since
/// tables can have composite primary key with many columns.
/// Which would require a `pk1 = value1 AND pk2 = value2`
extension CardinalityInferrer: ExprSyntaxVisitor {
    typealias ExprOutput = Set<Substring>
    
    mutating func visit(_ expr: LiteralExprSyntax) -> ExprOutput { [] }
    
    mutating func visit(_ expr: BindParameterSyntax) -> ExprOutput { [] }
    
    mutating func visit(_ expr: ColumnExprSyntax) -> ExprOutput {
        return switch expr.column {
        case .column(let column): [column.value]
        case .all: []
        }
    }
    
    mutating func visit(_ expr: PrefixExprSyntax) -> ExprOutput {
        return expr.rhs.accept(visitor: &self)
    }
    
    mutating func visit(_ expr: PostfixExprSyntax) -> ExprOutput {
        return expr.lhs.accept(visitor: &self)
    }
    
    mutating func visit(_ expr: BetweenExprSyntax) -> ExprOutput { [] }
    
    mutating func visit(_ expr: FunctionExprSyntax) -> ExprOutput { [] }
    
    mutating func visit(_ expr: CastExprSyntax) -> ExprOutput { [] }
    
    mutating func visit(_ expr: CaseWhenThenExprSyntax) -> ExprOutput { [] }
    
    mutating func visit(_ expr: GroupedExprSyntax) -> ExprOutput { [] }
    
    mutating func visit(_ expr: SelectExprSyntax) -> ExprOutput { [] }
    
    mutating func visit(_ expr: InvalidExprSyntax) -> ExprOutput { [] }
    
    mutating func visit(_ expr: InfixExprSyntax) -> ExprOutput {
        // Any operator other an an `=` or `AND` we cannot assume it will return a single value.
        // Example: `id = 1 OR id = 2`. Each side of the expr filtered on the pk
        // but it can return multiple values. We might be able to in the future do more.
        guard expr.operator.operator == .eq
                || expr.operator.operator == .eq2
                || expr.operator.operator == .and else { return [] }
        
        // `id = 1 AND parentId = 2` should return [id, parentId]
        return expr.lhs.accept(visitor: &self).union(expr.rhs.accept(visitor: &self))
    }
    
    mutating func visit(_ expr: ExistsExprSyntax) -> Set<Substring> { [] }
}
