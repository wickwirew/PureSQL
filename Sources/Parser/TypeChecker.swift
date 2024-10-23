//
//  TypeChecker.swift
//
//
//  Created by Wes Wickwire on 10/19/24.
//

import OrderedCollections
import Schema

public struct Scope {
    private(set) var tables: [TableName: TableSchema] = [:]
    
    enum ColumnResult: Equatable {
        case found(ColumnDef)
        case ambiguous
        case notFound
    }
    
    mutating func include(table: TableSchema) {
        tables[table.name] = table
    }
    
    func column(name: Identifier) -> ColumnResult {
        var result: ColumnResult = .notFound
        
        for table in tables.values {
            if let column = table.columns[name] {
                if result == .notFound {
                    return .ambiguous
                }
                
                result = .found(column)
            }
        }
        
        return result
    }
    
    func column(
        schema: Identifier?,
        table: Identifier,
        name: Identifier
    ) -> ColumnResult {
        guard let table = tables[TableName(schema: schema, name: table)],
              let column = table.columns[name] else { return .notFound }
        
        return .found(column)
    }
}

public struct TypeChecker {
    private let scope: Scope
    private var diagnostics: Diagnostics
    
    public init(scope: Scope, diagnostics: Diagnostics = Diagnostics()) {
        self.scope = scope
        self.diagnostics = diagnostics
    }
}

extension TypeChecker: ExprVisitor {
    public typealias Output = TypeName
    
    public mutating func visit(_ expr: LiteralExpr) throws -> TypeName {
        return switch expr.kind {
        case .numeric(_, let isInt): isInt ? .integer : .real
        case .string: .text
        case .blob: .blob
        case .null: .any
        case .true, .false: .bool
        case .currentTime, .currentDate, .currentTimestamp: .text
        }
    }
    
    public mutating func visit(_ expr: BindParameter) throws -> TypeName {
        fatalError()
    }
    
    public mutating func visit(_ expr: ColumnExpr) throws -> TypeName {
        let result: Scope.ColumnResult = if let table = expr.table {
            scope.column(schema: expr.schema, table: table, name: expr.column)
        } else {
            scope.column(name: expr.column)
        }
        
        switch result {
        case .found(let column):
            return column.type
        case .ambiguous:
            // TODO: Add dianostic
            return .any
        case .notFound:
            // TODO: Add dianostic
            return .any
        }
    }
    
    public mutating func visit(_ expr: PrefixExpr) throws -> TypeName {
        return try expr.rhs.accept(visitor: &self)
    }
    
    public mutating func visit(_ expr: InfixExpr) throws -> TypeName {
        let lhs = try expr.lhs.accept(visitor: &self)
        let rhs = try expr.rhs.accept(visitor: &self)
        
        switch expr.operator.operator {
        // Arithmetic Operators
        case .plus, .minus, .multiply, .divide, .bitwuseOr,
                .bitwiseAnd, .shl, .shr, .mod:
            return lhs.unify(with: rhs)
        // Comparisons
        case .eq, .eq2, .neq, .neq2, .lt, .gt, .lte, .gte, .is,
                .notNull, .notnull, .in, .like, .isNot, .isDistinctFrom,
                .isNotDistinctFrom, .between, .and, .or, .isnull:
            return .bool

        case .tilde: return .any
        case .collate: return lhs
        case .concat: return .text
        case .arrow, .doubleArrow: return .any
        case .escape: return lhs
        case .match: return .any
        case .regexp: return .any
        case .glob: return .any
        
        case .not: return .any
        }
    }
    
    public mutating func visit(_ expr: PostfixExpr) throws -> TypeName {
        return try expr.lhs.accept(visitor: &self)
    }
    
    public mutating func visit(_ expr: BetweenExpr) throws -> TypeName {
        let value = try expr.value.accept(visitor: &self)
        
        if value != .bool {
//            diagnostics.add(Diagnostic(expected: .bool, got: value, at: expr.range))
        }
        
        if try !expr.lower.accept(visitor: &self).isNumber {
            fatalError()
        }
        
        if try !expr.upper.accept(visitor: &self).isNumber {
            fatalError()
        }
        
        return .bool
    }
    
    public mutating func visit(_ expr: FunctionExpr) throws -> TypeName {
        fatalError()
    }
    
    public mutating func visit(_ expr: CastExpr) throws -> TypeName {
        fatalError()
    }
    
    public mutating func visit(_ expr: Expression) throws -> TypeName {
        fatalError()
    }
    
    public mutating func visit(_ expr: CaseWhenThenExpr) throws -> TypeName {
        fatalError()
    }
    
    public mutating func visit(_ expr: GroupedExpr) throws -> TypeName {
        fatalError()
    }
}

extension TypeName {
    func unify(with typeName: TypeName) -> TypeName {
        guard self.resolved != typeName.resolved else { return  self }
        
        switch (resolved, typeName.resolved) {
        case (.integer, .int): return .integer
        case (.int, .integer): return .integer
        case (.integer, .real): return .real
        case (.real, .integer): return .real
        case (.int, .real): return .real
        case (.real, .int): return .real
        case (.text, _): return .text
        case (_, .text): return .text
        default: return .any
        }
    }
}
