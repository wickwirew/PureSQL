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
    
    mutating func sanitize<S: StmtSyntax>(_ stmt: S, in source: String) -> String {
        let rangesToRemove = stmt.accept(visitor: &self)
        
        guard !rangesToRemove.isEmpty else { return "\(source[stmt.range]);" }
        
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
        
        return "\(final.trimmingCharacters(in: .whitespaces));"
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
    
    /// Splits the source into segments where each segment is either
    /// just text or a spot where a list/row parameter must have its
    /// bind parameter indices inserted at runtime.
    ///
    /// SQLite does not support by default passing in a list as a parameter
    /// for statements like `bar IN :elements`.
    /// The above example will need to get rewritten as `bar IN (?, ?, ?)`
    /// having a `?` for each element in the list.
    func segment(statement: Statement) -> [SourceSegment] {
        // All row parameters in order from start to finish associated to the
        // parameter they appeared from.
        let rowRanges: [(Range<Substring.Index>, Parameter<String>)] = statement.parameters
            .compactMap { _, param -> [(Range<Substring.Index>, Parameter<String>)]? in
                guard case .row = param.type else { return nil }
                return param.ranges.map { ($0, param) }
            }
            .flatMap(\.self)
            .sorted { $0.0.lowerBound < $1.0.lowerBound }
        
        guard !rowRanges.isEmpty else {
            return [.text(statement.sanitizedSource[...])]
        }
        
        guard rangesToRemove.isEmpty else {
            // We cannot support both removing parts of the source SQL
            // while also segmenting out the source for row parameters.
            // The initial removal would invalidate the ranges in the
            // parameter syntax nodes.
            //
            // In the future we could segment first then remove but
            // not really worth it since only migrations have syntax removed
            // and queries only have inputs
            fatalError("Removed syntax from source and have list inputs")
        }
        
        var segments: [SourceSegment] = []
        var startIndex = statement.syntax.range.lowerBound
        
        for (rowRange, param) in rowRanges {
            let textRange = startIndex..<rowRange.lowerBound
            let text = statement.sanitizedSource[textRange]
            segments.append(.text(text))
            segments.append(.rowParam(param))
            startIndex = rowRange.upperBound
        }
        
        // If the last range wasnt to the end of the string
        // then make sure to append the rest
        if startIndex < statement.syntax.range.upperBound {
            let textRange = startIndex..<statement.syntax.range.upperBound
            let text = statement.sanitizedSource[textRange]
            segments.append(.text(text))
        }
        
        return segments
    }
}

extension Sanitizer: StmtSyntaxVisitor {
    func visit(_ stmt: borrowing CreateTableStmtSyntax) -> [Range<Substring.Index>] {
        switch stmt.kind {
        case .columns(let columns):
            return columns.values.compactMap { $0.type.alias?.range }
        case .select:
            return []
        }
    }
    
    func visit(_ stmt: borrowing AlterTableStmtSyntax) -> [Range<Substring.Index>] {
        return switch stmt.kind {
        case .addColumn(let c): c.type.alias.map { [$0.range] } ?? []
        default: []
        }
    }
    
    func visit(_ stmt: borrowing EmptyStmtSyntax) -> [Range<Substring.Index>] { [] }
    
    func visit(_ stmt: borrowing SelectStmtSyntax) -> [Range<Substring.Index>] { [] }
    
    func visit(_ stmt: borrowing InsertStmtSyntax) -> [Range<Substring.Index>] { [] }
    
    func visit(_ stmt: borrowing UpdateStmtSyntax) -> [Range<Substring.Index>] { [] }
    
    func visit(_ stmt: borrowing DeleteStmtSyntax) -> [Range<Substring.Index>] { [] }
    
    func visit(_ stmt: borrowing QueryDefinitionStmtSyntax) -> [Range<Substring.Index>] {
        // Remove the `DEFINE QUERY name AS`
        return [stmt.range.lowerBound..<stmt.statement.range.lowerBound]
    }
    
    func visit(_ stmt: borrowing PragmaStmt) -> [Range<Substring.Index>] { [] }
    
    func visit(_ stmt: borrowing DropTableStmtSyntax) -> [Range<Substring.Index>] { [] }
    
    func visit(_ stmt: borrowing CreateIndexStmtSyntax) -> [Range<Substring.Index>] { [] }
    
    func visit(_ stmt: borrowing DropIndexStmtSyntax) -> [Range<Substring.Index>] { [] }
    
    func visit(_ stmt: borrowing ReindexStmtSyntax) -> [Range<Substring.Index>] { [] }
    
    func visit(_ stmt: borrowing CreateViewStmtSyntax) -> [Range<Substring.Index>] { [] }
    
    func visit(_ stmt: borrowing CreateVirtualTableStmtSyntax) -> [Range<Substring.Index>] {
        return stmt.arguments.flatMap { argument -> [Range<Substring.Index>] in
            guard case let .fts5Column(_, typeName, notNull, _) = argument else { return [] }
            if let typeName, let notNull { return [typeName.range, notNull] }
            if let typeName { return [typeName.range] }
            if let notNull { return [notNull] }
            return []
        }
    }
}
