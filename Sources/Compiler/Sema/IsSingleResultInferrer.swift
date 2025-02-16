//
//  IsSingleResultInferrer.swift
//  Feather
//
//  Created by Wes Wickwire on 2/16/25.
//

/// Infers the amount of items returned in a query.
/// This allows the generation to be smart and set the
/// return type to an Array only if needed.
struct IsSingleResultInferrer {
    let schema: Schema
    
    mutating func infer(_ statement: consuming Statement) -> Statement {
        guard statement.syntax.accept(visitor: &self) else { return statement }
        return Statement(
            name: statement.name,
            signature: statement.signature.withSingleOutput(),
            syntax: statement.syntax
        )
    }
}

/// Returns `true` if the query/statement will only return one value.
extension IsSingleResultInferrer: StmtSyntaxVisitor {
    mutating func visit(_ stmt: borrowing CreateTableStmtSyntax) -> Bool { true }
    
    mutating func visit(_ stmt: borrowing AlterTableStmtSyntax) -> Bool { true }
    
    mutating func visit(_ stmt: borrowing EmptyStmtSyntax) -> Bool { true }
    
    mutating func visit(_ stmt: borrowing SelectStmtSyntax) -> Bool {
        // See if there is a LIMIT 1 since this will always return a single result regardless
        // of what happens in the query.
        if case let .literal(e) = stmt.limit?.expr, case let .numeric(i, _) = e.kind, i == 1 {
            return true
        }
        
        // A compound select since its bringing in multiple tables we could never know whether
        // a single result could be returned, and it is unlikely to do so.
        guard case let .single(selectCore) = stmt.selects.value else {
            return false
        }
        
        // Only other case is `VALUES` which will always return a single result
        guard case let .select(select) = selectCore else {
            return true
        }

        // If its not filtered down with a `WHERE` it will always return more
        guard let filter = select.where else { return false }
        
        if case let .join(join) = select.from {
            // If there are joins just return that it returns many rows.
            // In the future we could see if the joins are all a 1:1 and maybe
            // so some better inference but this will do for now. Adding a
            // `LIMIT 1` to the query will get them the result they want if
            // it is inferred as a list.
            guard join.joins.isEmpty else { return false }
            
            // If its not against a table we cannot infer it.
            guard case let .table(table) = join.tableOrSubquery else { return false }
            
            // If we cannot find the table something upstream will have already emitted
            // diagnositic so just exit
            guard let t = schema[table.name.value] else { return false }
            
            // If they had filtering on all primary keys we can assume a single
            // result will be returned.
            let filteredPrimaryKeys = filter.accept(visitor: &self)
            return !t.primaryKey.contains{ !filteredPrimaryKeys.contains($0) }
        }
        
        return false
    }
    
    mutating func visit(_ stmt: borrowing InsertStmtSyntax) -> Bool {
        return true
    }
    
    mutating func visit(_ stmt: borrowing QueryDefinitionStmtSyntax) -> Bool {
        return stmt.statement.accept(visitor: &self)
    }
}

/// We need to look for a `primaryKey = value`. This can get complicated since
/// tables can have composite primary key with many columns.
/// Which would require a `pk1 = value1 AND pk2 = value2`
extension IsSingleResultInferrer: ExprSyntaxVisitor {
    typealias ExprOutput = Set<Substring>
    
    mutating func visit(_ expr: borrowing LiteralExprSyntax) -> ExprOutput { [] }
    
    mutating func visit(_ expr: borrowing BindParameterSyntax) -> ExprOutput { [] }
    
    mutating func visit(_ expr: borrowing ColumnExprSyntax) -> ExprOutput {
        return [expr.column.value]
    }
    
    mutating func visit(_ expr: borrowing PrefixExprSyntax) -> ExprOutput {
        return expr.rhs.accept(visitor: &self)
    }
    
    mutating func visit(_ expr: borrowing PostfixExprSyntax) -> ExprOutput {
        return expr.lhs.accept(visitor: &self)
    }
    
    mutating func visit(_ expr: borrowing BetweenExprSyntax) -> ExprOutput { [] }
    
    mutating func visit(_ expr: borrowing FunctionExprSyntax) -> ExprOutput { [] }
    
    mutating func visit(_ expr: borrowing CastExprSyntax) -> ExprOutput { [] }
    
    mutating func visit(_ expr: borrowing CaseWhenThenExprSyntax) -> ExprOutput { [] }
    
    mutating func visit(_ expr: borrowing GroupedExprSyntax) -> ExprOutput { [] }
    
    mutating func visit(_ expr: borrowing SelectExprSyntax) -> ExprOutput { [] }
    
    mutating func visit(_ expr: borrowing InvalidExprSyntax) -> ExprOutput { [] }
    
    mutating func visit(_ expr: borrowing InfixExprSyntax) -> ExprOutput {
        // Any operator other an an `=` or `AND` we cannot assume it will return a single value.
        // Example: `id = 1 OR id = 2`. Each side of the expr filtered on the pk
        // but it can return multiple values. We might be able to in the future do more.
        guard expr.operator.operator == .eq
                || expr.operator.operator == .eq2
                || expr.operator.operator == .and else { return [] }
        
        // `id = 1 AND parentId = 2` should return [id, parentId]
        return expr.lhs.accept(visitor: &self).union(expr.rhs.accept(visitor: &self))
    }
}
