//
//  Sanitizer.swift
//  Feather
//
//  Created by Wes Wickwire on 2/22/25.
//

/// We have a little bit of syntax on top of SQLs base syntax.
/// This removes those portions so the SQL does not contain any
/// invalid syntax
struct Sanitizer {
    private var rangesToRemove: [Range<Substring.Index>] = []
    
    static func sanitize<S: StmtSyntax>(_ stmt: S, in source: String) -> String {
        var sanitizer = Sanitizer()
        return sanitizer.sanitize(stmt, in: source)
    }
    
    mutating func sanitize<S: StmtSyntax>(_ stmt: S, in source: String) -> String {
        let rangesToRemove = stmt.accept(visitor: &self)
        
        guard !rangesToRemove.isEmpty else { return String(source[stmt.range]) }
        
        var final = ""
        var start = stmt.range.lowerBound
        
        // Remove in reverse so the range start does not change.
        for range in rangesToRemove.sorted(by: { $0.lowerBound < $1.lowerBound }) {
            final.append(contentsOf: source[start..<range.lowerBound])
            start = range.upperBound
        }
        
        if start < stmt.range.upperBound {
            final.append(contentsOf: source[start..<stmt.range.upperBound])
        }
        
        return final
    }
    
    mutating func finalize(in original: String) -> String {
        var sanitized = original
        
        guard !rangesToRemove.isEmpty else { return sanitized }
        
        // Remove in reverse so the range start does not change.
        for range in rangesToRemove.sorted(by: { $0.lowerBound > $1.lowerBound }) {
            sanitized.removeSubrange(range)
        }
        
        return sanitized
    }
    
    mutating func combine<S: StmtSyntax>(_ stmt: S) {
        rangesToRemove.append(contentsOf: stmt.accept(visitor: &self))
    }
}

extension Sanitizer: StmtSyntaxVisitor {
    mutating func visit(_ stmt: borrowing CreateTableStmtSyntax) -> [Range<Substring.Index>] {
        switch stmt.kind {
        case .columns(let columns):
            return columns.values.compactMap { $0.type.alias?.range }
        case .select:
            return []
        }
    }
    
    mutating func visit(_ stmt: borrowing AlterTableStmtSyntax) -> [Range<Substring.Index>] {
        return []
    }
    
    mutating func visit(_ stmt: borrowing EmptyStmtSyntax) -> [Range<Substring.Index>] { [] }
    
    mutating func visit(_ stmt: borrowing SelectStmtSyntax) -> [Range<Substring.Index>] { [] }
    
    mutating func visit(_ stmt: borrowing InsertStmtSyntax) -> [Range<Substring.Index>] { [] }
    
    mutating func visit(_ stmt: borrowing UpdateStmtSyntax) -> [Range<Substring.Index>] { [] }
    
    mutating func visit(_ stmt: borrowing DeleteStmtSyntax) -> [Range<Substring.Index>] { [] }
    
    mutating func visit(_ stmt: borrowing QueryDefinitionStmtSyntax) -> [Range<Substring.Index>] {
        // Remove the `DEFINE QUERY name AS`
        return [stmt.range.lowerBound..<stmt.statement.range.lowerBound]
    }
    
    mutating func visit(_ stmt: borrowing PragmaStmt) -> [Range<Substring.Index>] { [] }
}
