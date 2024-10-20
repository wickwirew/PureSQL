//
//  TypeChecker.swift
//
//
//  Created by Wes Wickwire on 10/19/24.
//

import OrderedCollections


struct Scope {
    private(set) var tables: [TableName: TableSchema] = [:]
    
    enum ColumnResult: Equatable {
        case found(ColumnDef)
        case ambiguous
        case notFound
    }
    
    mutating func include(table: TableSchema) {
        tables[table.name] = table
    }
    
    func column(name: Substring) -> ColumnResult {
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
        schema: Substring?,
        table: Substring,
        name: Substring
    ) -> ColumnResult {
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
}

struct TypeChecker {
    private let scope: Scope
}

extension TypeChecker: ExprVisitor {
    typealias Output = Ty
    
    func visit(_ expr: Literal) throws -> Ty {
        return switch expr {
        case .numeric(_, let isInt): isInt ? .integer : .real
        case .string: .text
        case .blob: .blob
        case .null: .any
        case .true, .false: .bool
        case .currentTime, .currentDate, .currentTimestamp: .text
        }
    }
    
    func visit(_ expr: BindParameter) throws -> Ty {
        fatalError()
    }
    
    func visit(_ expr: ColumnExpr) throws -> Ty {
        let result: Scope.ColumnResult = if let table = expr.table {
            scope.column(schema: expr.schema, table: table, name: expr.column)
        } else {
            scope.column(name: expr.column)
        }
        
        switch result {
        case .found(let columnDef):
            return Ty.bool
        case .ambiguous:
            <#code#>
        case .notFound:
            <#code#>
        }
//        guard let table = tables[expr.table]
        fatalError()
    }
    
    func visit(_ expr: PrefixExpr) throws -> Ty {
        fatalError()
    }
    
    func visit(_ expr: InfixExpr) throws -> Ty {
        fatalError()
    }
    
    func visit(_ expr: PostfixExpr) throws -> Ty {
//        return try expr.lhs.accept(visitor: self)
        fatalError()
    }
    
    func visit(_ expr: BetweenExpr) throws -> Ty {
        return .bool
    }
    
    func visit(_ expr: FunctionExpr) throws -> Ty {
        fatalError()
    }
    
    func visit(_ expr: CastExpr) throws -> Ty {
        fatalError()
    }
    
    func visit(_ expr: Expression) throws -> Ty {
        fatalError()
    }
    
    func visit(_ expr: CaseWhenThen) throws -> Ty {
        fatalError()
    }
}
