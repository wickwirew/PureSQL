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
    
    /// Consumes the token
    private mutating func consume() throws {
        current = peek
        peek = try lexer.next()
    }
    
    /// Consumes the token and validates that the token matches the input kind.
    /// If they are different, an error is thrown.
    private mutating func consume(_ kind: Token.Kind) throws {
        guard current.kind == kind else {
            throw ParsingError.unexpectedToken(of: current.kind, at: current.range)
        }
        
        try consume()
    }
    
    /// Consumes the token if the kind matches the current token.
    private mutating func consume(if kind: Token.Kind) throws -> Bool {
        guard current.kind == kind else {
            return false
        }
        
        try consume()
        return true
    }
    
    /// Parses out a symbol from the current token.
    private mutating func parseSymbol() throws -> Substring {
        guard case let .symbol(sym) = current.kind else {
            throw ParsingError.expectedSymbol(at: current.range)
        }
        
        try consume()
        return sym
    }
    
    /// Parses out a numeric value from the current token.
    private mutating func parseNumeric() throws -> Numeric {
        guard case let .numeric(num) = current.kind else {
            throw ParsingError.expectedNumeric(at: current.range)
        }
        
        try consume()
        return num
    }
    
    /// Parses out a SQLite literal from the current token.
    private mutating func parseLiteral() throws -> Literal {
        // TODO: Rest of literals
        switch current.kind {
        case .numeric(let value):
            try consume()
            return .numeric(value)
        case .string(let value):
            try consume()
            return .string(value)
        default:
            throw ParsingError(description: "Invalid Literal '\(current)'", sourceRange: current.range)
        }
    }
    
    /// https://www.sqlite.org/lang_createtable.html
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
    
    /// Parses a column definition that can be in a create table
    /// or an alter statement.
    ///
    /// https://www.sqlite.org/syntax/column-def.html
    private mutating func parseColumnDef() throws -> ColumnDef {
        let name = try parseSymbol()
        let type = try parseTy()
        let constraints = try parseColumnConstraints()
        return ColumnDef(name: name, type: type, constraints: constraints)
    }
    
    /// Parses out a type, from a SQLite type name.
    ///
    /// https://www.sqlite.org/syntax/type-name.html
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
    
    /// Parses any constraints on a column.
    ///
    /// Example:
    /// PRIMARY KEY ASC ON CONFLICT REPLACE AUTOINCREMENT
    /// NOT NULL ON CONFLICT IGNORE
    /// UNIQUE ON CONFLICT IGNORE
    /// CHECK (expr)
    ///
    /// https://www.sqlite.org/syntax/column-constraint.html
    private mutating func parseColumnConstraints() throws -> [ColumnConstraint] {
        var constraints = [ColumnConstraint]()
        
        // Get the name of the constraint if any
        let name = try consume(if: .constraint) ? try parseSymbol() : nil
        
        while true {
            if try consume(if: .primary) {
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
                    kind: .primaryKey(order: order, conflictClause, autoincrement: autoincrement)
                )
                
                constraints.append(constraint)
            } else if try consume(if: .not) {
                try consume(.null)
                let conflictClause = try parseConflictClause()
                constraints.append(ColumnConstraint(name: name, kind: .notNull(conflictClause)))
            } else if try consume(if: .unique) {
                let conflictClause = try parseConflictClause()
                constraints.append(ColumnConstraint(name: name, kind: .unique(conflictClause)))
            } else if try consume(if: .check) {
                try consume(.openParen)
                let expr = try parseExpr()
                try consume(.closeParen)
                constraints.append(ColumnConstraint(name: name, kind: .check(expr)))
            } else if try consume(if: .default) {
                if try consume(if: .openParen) {
                    let expr = try parseExpr()
                    try consume(.closeParen)
                    constraints.append(ColumnConstraint(name: name, kind: .default(.expr(expr))))
                } else {
                    let value = try parseLiteral()
                    constraints.append(ColumnConstraint(name: name, kind: .default(.literal(value))))
                }
            } else if try consume(if: .collate) {
                let name = try parseSymbol()
                constraints.append(ColumnConstraint(name: name, kind: .collate(name)))
            } else if try consume(if: .references) {
                let foreignKey = try parseForeignKeyClause()
                constraints.append(ColumnConstraint(name: name, kind: .foreignKey(foreignKey)))
            } else if try consume(if: .generated) {
                try consume(.always)
                try consume(.as)
                try consume(.openParen)
                let expr = try parseExpr()
                try consume(.closeParen)
                
                let generated: ColumnConstraint.Generated? = if try consume(if: .stored) {
                    .stored
                } else if try consume(if: .virtual) {
                    .virtual
                } else {
                    nil
                }
                
                constraints.append(ColumnConstraint(name: name, kind: .generated(expr, generated)))
            } else if try consume(if: .as) {
                try consume(.openParen)
                let expr = try parseExpr()
                try consume(.closeParen)
                
                let generated: ColumnConstraint.Generated? = if try consume(if: .stored) {
                    .stored
                } else if try consume(if: .virtual) {
                    .virtual
                } else {
                    nil
                }
                
                constraints.append(ColumnConstraint(name: name, kind: .generated(expr, generated)))
            } else {
                return constraints
            }
        }
    }
    
    /// Parses a conflict clause if one exists.
    ///
    /// Example:
    /// ON CONFLICT IGNORE
    ///
    /// https://www.sqlite.org/syntax/conflict-clause.html
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
            throw error("Invalid Conflict Clause")
        }
    }
    
    /// Parses out a foreign key clause for column definition.
    ///
    /// Example:
    /// REFERENCES user(id) ON DELETE CASCADE
    /// REFERENCES user(id) ON DELETE SET NULL
    ///
    /// https://www.sqlite.org/syntax/foreign-key-clause.html
    private mutating func parseForeignKeyClause() throws -> ForeignKeyClause {
        // Assumes 'REFERENCES' has already been consumed
        let table = try parseSymbol()
        
        var columns: [Substring] = []
        if try consume(if: .openParen) {
            repeat {
                columns.append(try parseSymbol())
            } while try consume(if: .comma)
        }
        try consume(.closeParen)
        
        if try consume(if: .on) {
            let on: ForeignKeyClause.On = if try consume(if: .delete) {
                .delete
            } else if try consume(if: .update) {
                .update
            } else {
                throw expected(.delete, .update)
            }
            
            return ForeignKeyClause(
                foreignTable: table,
                foreignColumns: columns,
                action: .onDo(on, try parseForeignKeyClauseDo())
            )
        } else if try consume(if: .match) {
            let name = try parseSymbol()
            
            guard let action = try parseForeignKeyClauseAction() else {
                throw error("Expected clause after '\(Token.Kind.match)'")
            }
            
            return ForeignKeyClause(
                foreignTable: table,
                foreignColumns: columns,
                action: .match(name, action)
            )
        } else if try consume(if: .not) {
            try consume(.deferrable)
            return ForeignKeyClause(
                foreignTable: table,
                foreignColumns: columns,
                action: .notDeferrable(try parseForeignKeyClauseDeferrable())
            )
        } else if try consume(if: .deferrable) {
            return ForeignKeyClause(
                foreignTable: table,
                foreignColumns: columns,
                action: .deferrable(try parseForeignKeyClauseDeferrable())
            )
        } else {
            return ForeignKeyClause(foreignTable: table, foreignColumns: columns, action: nil)
        }
    }
    
    /// Parses the action part of the foreign key clause.
    ///
    /// Example:
    /// ON DELETE CASCADE
    ///
    /// https://www.sqlite.org/syntax/foreign-key-clause.html
    private mutating func parseForeignKeyClauseAction() throws -> ForeignKeyClause.Action? {
        if try consume(if: .on) {
            let on: ForeignKeyClause.On = if try consume(if: .delete) {
                .delete
            } else if try consume(if: .update) {
                .update
            } else {
                throw expected(.delete, .update)
            }
            
            return .onDo(on, try parseForeignKeyClauseDo())
        } else if try consume(if: .match) {
            let name = try parseSymbol()
            guard let action = try parseForeignKeyClauseAction() else {
                throw error("Expected clause after '\(Token.Kind.match)'")
            }
            
            return .match(name, action)
        } else if try consume(if: .not) {
            try consume(.deferrable)
            return .notDeferrable(try parseForeignKeyClauseDeferrable())
        } else if try consume(if: .deferrable) {
            return .deferrable(try parseForeignKeyClauseDeferrable())
        } else {
            return nil
        }
    }
    
    /// INITIALLY DEFERRED
    /// INITIALLY IMMEDIATE
    ///
    /// https://www.sqlite.org/syntax/foreign-key-clause.html
    private mutating func parseForeignKeyClauseDeferrable() throws -> ForeignKeyClause.Deferrable {
        try consume(.initially)
        return if try consume(if: .deferred) {
            .initiallyDeferred
        } else if try consume(if: .immediate) {
            .initiallyImmediate
        } else {
            throw expected(.deferred, .immediate)
        }
    }
    
    /// Parses the final action of what do do on a foreign key 'ON' clause.
    ///
    /// Example:
    /// ON DELETE CASCADE
    ///
    /// This would parse out the 'CASCADE' part.
    ///
    /// https://www.sqlite.org/syntax/foreign-key-clause.html
    private mutating func parseForeignKeyClauseDo() throws -> ForeignKeyClause.Do {
        if try consume(if: .set) {
            if try consume(if: .null) {
                return .setNull
            } else if try consume(if: .default) {
                return .setDefault
            } else {
                throw expected(.null, .default)
            }
        } else if try consume(if: .cascade) {
            return .cascade
        } else if try consume(if: .restrict) {
            return .restrict
        } else if try consume(if: .no) {
            try consume(.action)
            return .noAction
        } else {
            throw expected(.set, .cascade, .restrict, .no)
        }
    }
    
    
}

// MARK: - Expressions
extension Parser {
    private mutating func parseExpr() throws -> Expr {
        Expr()
    }
}

// MARK: - Errors
extension Parser {
    /// Returns an error message stating that is expected one of the following tokens
    private func expected(_ tokenKinds: Token.Kind...) -> ParsingError {
        error("Expected \(tokenKinds.map(\.description).joined(separator: " or "))")
    }
    
    /// Returns an error with the given message
    private func error(_ description: String) -> ParsingError {
        ParsingError(description: description, sourceRange: current.range)
    }
}
