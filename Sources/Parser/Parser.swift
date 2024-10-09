//
//  Parser.swift
//
//
//  Created by Wes Wickwire on 10/8/24.
//

import Schema

struct Parser {
    var lexer: Lexer
    var current: Token
    var peek: Token
    
    init(lexer: Lexer) throws {
        self.lexer = lexer
        self.current = try self.lexer.next()
        self.peek = try self.lexer.next()
    }
    
    mutating func next() throws -> Stmt {
        switch current.kind {
        case .create:
            try consume()
            
            switch current.kind {
            case .table, .temp, .temporary:
                return try .createTable(parseCreateTable())
            default:
                fatalError()
            }
        default:
            fatalError()
        }
    }
    
    private mutating func consume() throws {
        current = peek
        peek = try lexer.next()
    }
    
    private mutating func consume(_ kind: Token.Kind) throws {
        guard current.kind == kind else {
            throw ParsingError.unexpectedToken(of: current.kind, at: current.range)
        }
        
        try consume()
    }
    
    private mutating func consume(if kind: Token.Kind) throws -> Bool {
        guard current.kind == kind else {
            return false
        }
        
        try consume()
        return true
    }
    
    private mutating func parseSymbol() throws -> Substring {
        guard case let .symbol(sym) = current.kind else {
            throw ParsingError.expectedSymbol(at: current.range)
        }
        
        try consume()
        return sym
    }
    
    private mutating func parseNumeric() throws -> Numeric {
        guard case let .numeric(num) = current.kind else {
            throw ParsingError.expectedNumeric(at: current.range)
        }
        
        try consume()
        return num
    }
    
    // https://www.sqlite.org/lang_createtable.html
    private mutating func parseCreateTable() throws -> CreateTableStmt {
        let isTemporary = current.kind == .temporary || current.kind == .temp
        if isTemporary {
            try consume()
        }
        
        try consume(.table)
        
        let ifNotExists: Bool
        if current.kind == .if {
            try consume()
            try consume(.not)
            try consume(.exists)
            ifNotExists = true
        } else {
            ifNotExists = false
        }
        
        let schemaName: Substring?
        let name: Substring
        if peek.kind == .dot {
            schemaName = try parseSymbol()
            try consume(.dot)
            name = try parseSymbol()
        } else {
            schemaName = nil
            name = try parseSymbol()
        }
        
        if current.kind == .as {
            fatalError("Implement SELECT")
        } else {
            let columns = try parseColumns()

            return CreateTableStmt(
                name: name,
                schemaName: schemaName ?? "",
                isTemporary: isTemporary,
                onlyIfExists: ifNotExists,
                kind: .columns(columns),
                constraints: [],
                options: []
            )
        }
    }
    
    private mutating func parseColumns() throws -> [Substring: ColumnDef] {
        try consume(.openParen)
        var columns = [Substring: ColumnDef]()
        
        while current.kind != .closeParen {
            let column = try parseColumnDef()
            columns[column.name] = column
            
            if current.kind == .comma {
                try consume()
            }
        }
        
        try consume(.closeParen)
        
        return columns
    }
    
    // https://www.sqlite.org/syntax/column-def.html
    private mutating func parseColumnDef() throws -> ColumnDef {
        let name = try parseSymbol()
        let type = try parseTy()
        let constraints = try parseColumnConstraints()
        return ColumnDef(name: name, type: type, constraints: constraints)
    }
    
    // https://www.sqlite.org/syntax/type-name.html
    private mutating func parseTy() throws -> Ty {
        let name = try parseSymbol()
        
        // Just a helper function to create a Ty and if nil throw an error
        func ty(from first: Numeric? = nil, and second: Numeric? = nil) throws -> Ty {
            guard let ty = Ty(name: name, with: first, and: second) else {
                throw ParsingError.unknown(type: name, at: current.range)
            }
            
            return ty
        }
        
        if current.kind == .openParen {
            try consume()
            let first = try parseNumeric()
            
            let type: Ty
            if current.kind == .comma {
                try consume()
                type = try ty(from: first, and: try parseNumeric())
            } else {
                type = try ty(from: first)
            }
            
            try consume(.closeParen)
            return type
        } else {
            guard let ty = Ty(name: name) else {
                throw ParsingError.unknown(type: name, at: current.range)
            }
            
            return ty
        }
    }
    
    // https://www.sqlite.org/syntax/column-constraint.html
    private mutating func parseColumnConstraints() throws -> [ColumnConstraint] {
        var constraints = [ColumnConstraint]()
        
        let name = try consume(if: .constraint) ? try parseSymbol() : nil
        
        while true {
            switch current.kind {
            case .primary:
                try consume()
                try consume(.key)
                
                let order: Order? = if try consume(if: .asc) {
                    .asc
                } else if try consume(if: .desc) {
                    .desc
                } else {
                    nil
                }
                
                let conflictClause = try parseConflictClause()
                let autoincrement = try consume(if: .autoincrement)
                
                let constraint = ColumnConstraint(
                    name: name,
                    kind: .primaryKey(order: order,
                    conflictClause,
                    autoincrement: autoincrement)
                )
                
                constraints.append(constraint)
            default:
                return constraints
            }
        }
    }
    
    private mutating func parseConflictClause() throws -> ConfictClause? {
        guard current.kind == .on else {
            return nil
        }
        
        try consume()
        try consume(.conflict)
        
        switch current.kind {
        case .rollback:
            try consume()
            return .rollback
        case .abort:
            try consume()
            return .abort
        case .fail:
            try consume()
            return .fail
        case .ignore:
            try consume()
            return .ignore
        case .replace:
            try consume()
            return .replace
        default:
            throw ParsingError(description: "Invalid Conflict Clause", sourceRange: current.range)
        }
    }
}

func unimplemented() -> Never {
    fatalError("Unimplemented")
}
