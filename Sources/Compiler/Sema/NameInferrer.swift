//
//  NameInferrer.swift
//  Feather
//
//  Created by Wes Wickwire on 2/23/25.
//

/// On top of inferring types we need to infer names for bind parameters.
///
/// Example:
/// Here is a simple select, with one input parameter. The generated code
/// needs a name for the value. Since it is being compared with the column
/// `bar` we can infer the param name to be `bar`.
/// `SELECT * FROM foo WHERE bar = ?`
struct NameInferrer {
    /// Any name that has been inferred so far.
    private var inferredNames: [BindParameterSyntax.Index: Substring] = [:]
    
    /// Infers any names in the expression. The result is either a name
    /// or a bind parameter than needs a name. This can be used to
    /// `suggest` a name if the caller can provide some extra context.
    @discardableResult
    mutating func infer<E: ExprSyntax>(_ expr: E) -> Name {
        return expr.accept(visitor: &self)
    }
    
    /// Gets the inferred or explicit bind parameter name at the given index.
    func parameterName(at index: BindParameterSyntax.Index) -> Substring? {
        return inferredNames[index]
    }
    
    /// If the bind parameter does not have a name already it will
    /// use the suggestion.
    mutating func suggest(name: Substring, for names: Name) {
        guard case let .needed(index) = names else { return }
        suggest(name: name, for: index)
    }
    
    /// If the bind parameter does not have a name already it will
    /// use the suggestion.
    mutating func suggest(name: Substring, for index: BindParameterSyntax.Index) {
        guard inferredNames[index] == nil else { return }
        inferredNames[index] = name
    }
    
    /// Combines all name results together.
    private mutating func unify(all names: [Name]) -> Name {
        var iter = names.makeIterator()
        guard var result = iter.next() else { return .none }
        
        while let next = iter.next() {
            result = unify(names: result, with: next)
        }
        
        return result
    }
    
    /// Combines the two name results together.
    /// If one has a name and the other needs one
    /// the name can be inferred.
    ///
    /// If a name is inferred, `.none` will be returned
    /// since the `.some` name is used and the `.needed`
    /// no longer needs a name
    private mutating func unify(
        names lhs: Name,
        with rhs: Name
    ) -> Name {
        switch (lhs, rhs) {
        case let (.needed(index), .some(name)):
            inferredNames[index] = name
            return .none
        case let (.some(name), .needed(index)):
            inferredNames[index] = name
            return .none
        case (.none, _):
            return rhs
        case (_, .none):
            return lhs
        default:
            return rhs
        }
    }
    
    private mutating func infer(select: SelectStmtSyntax) {
        if let cte = select.cte {
            infer(select: cte.select)
        }
        
        infer(selects: select.selects.value)
        
        for orderBy in select.orderBy {
            _ = orderBy.expr.accept(visitor: &self)
        }
        
        if let limit = select.limit {
            _ = limit.expr.accept(visitor: &self)
        }
    }
    
    private mutating func infer(selects: SelectStmtSyntax.Selects) {
        switch selects {
        case let .single(select):
            infer(select: select)
        case let .compound(first, _, second):
            infer(select: first)
            infer(selects: second)
        }
    }
    
    private mutating func infer(select: SelectCoreSyntax) {
        switch select {
        case .select(let select):
            for column in select.columns {
                switch column.kind {
                case let .expr(e, alias):
                    let eName = e.accept(visitor: &self)
                    
                    if let alias {
                        _ = unify(names: eName, with: .some(alias.identifier.value))
                    }
                default:
                    break
                }
            }
            
            switch select.from {
            case .join(let join):
                _ = infer(tableOrSubquery: join.tableOrSubquery)
            case .tableOrSubqueries(let tableOrSubqueries):
                for tableOrSubquery in tableOrSubqueries {
                    _ = infer(tableOrSubquery: tableOrSubquery)
                }
            case nil:
                break
            }
            
            if let whereExpr = select.where {
                _ = whereExpr.accept(visitor: &self)
            }
            
            if let groupBy = select.groupBy {
                for expr in groupBy.expressions {
                    _ = expr.accept(visitor: &self)
                }
            }
        case .values(let groups):
            for group in groups {
                for value in group {
                    _ = value.accept(visitor: &self)
                }
            }
        }
    }
    
    private mutating func infer(tableOrSubquery: TableOrSubquerySyntax) -> Name {
        switch tableOrSubquery.kind {
        case .table:
            return .none
        case .tableFunction(_, _, let args, _):
            return args.reduce(.none) {
                unify(names: $0, with: $1.accept(visitor: &self))
            }
        case .subquery(let selectStmtSyntax, _):
            infer(select: selectStmtSyntax)
            return .none
        case .join(let joinClauseSyntax):
            return joinClauseSyntax.joins.reduce(.none) {
                unify(names: $0, with: infer(tableOrSubquery: $1.tableOrSubquery))
            }
        case .subTableOrSubqueries(let tableOrSubqueries, _):
            return tableOrSubqueries.reduce(.none) {
                unify(names: $0, with: infer(tableOrSubquery: $1))
            }
        }
    }
}

extension NameInferrer: ExprSyntaxVisitor {
    typealias ExprOutput = Name
    
    mutating func visit(_ expr: borrowing LiteralExprSyntax) -> Name { .none }
    mutating func visit(_ expr: borrowing InvalidExprSyntax) -> Name { .none }
    
    mutating func visit(_ expr: borrowing PrefixExprSyntax) -> Name {
        return expr.rhs.accept(visitor: &self)
    }
    mutating func visit(_ expr: borrowing InfixExprSyntax) -> Name {
        let lhs = expr.lhs.accept(visitor: &self)
        let rhs = expr.rhs.accept(visitor: &self)
        
        if expr.operator.operator == .in || expr.operator.operator == .not(.in) {
            return unify(names: lhs.pluralize(), with: rhs)
        } else {
            return unify(names: lhs, with: rhs)
        }
    }
    mutating func visit(_ expr: borrowing PostfixExprSyntax) -> Name {
        return expr.lhs.accept(visitor: &self)
    }
    mutating func visit(_ expr: borrowing FunctionExprSyntax) -> Name {
        return unify(all: expr.args.map { $0.accept(visitor: &self) })
    }
    
    mutating func visit(_ expr: borrowing CastExprSyntax) -> Name {
        return expr.expr.accept(visitor: &self)
    }
    mutating func visit(_ expr: borrowing CaseWhenThenExprSyntax) -> Name {
        let `case` = expr.case?.accept(visitor: &self) ?? .none
        
        let whenThen = expr.whenThen.map {
            unify(names: $0.when.accept(visitor: &self), with: $0.then.accept(visitor: &self))
        }
        
        let `else` = expr.else?.accept(visitor: &self) ?? .none
        
        return unify(
            names: unify(names: `case`, with: unify(all: whenThen)),
            with: `else`
        )
    }
    mutating func visit(_ expr: borrowing GroupedExprSyntax) -> Name {
        return unify(all: expr.exprs.map{ $0.accept(visitor: &self) })
    }
    
    mutating func visit(_ expr: borrowing SelectExprSyntax) -> Name {
        infer(select: expr.select)
        return .none
    }
    
    mutating func visit(_ expr: borrowing ColumnExprSyntax) -> Name {
        .some(expr.column.value)
    }
    
    mutating func visit(_ expr: borrowing BindParameterSyntax) -> Name {
        switch expr.kind {
        case let .named(name):
            inferredNames[expr.index] = name.value
            return .none
        case .unnamed:
            return .needed(index: expr.index)
        }
    }
    
    mutating func visit(_ expr: borrowing BetweenExprSyntax) -> Name {
        let value = expr.value.accept(visitor: &self)
        let lower = expr.lower.accept(visitor: &self)
        let upper = expr.upper.accept(visitor: &self)

        return unify(
            names: unify(names: value.append("Lower"), with: lower),
            with: unify(names: value.append("Upper"), with: upper)
        )
    }
}
