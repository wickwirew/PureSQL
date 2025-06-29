//
//  Rewriter.swift
//  Otter
//
//  Created by Wes Wickwire on 2/22/25.
//

/// We have a little bit of syntax on top of SQLs base syntax.
/// This removes those portions so the SQL does not contain any
/// invalid syntax
struct Rewriter {
    private var rangesToRemove: [Range<Substring.Index>] = []
    
    mutating func rewrite<S: StmtSyntax>(
        _ stmt: S,
        with parameters: [Parameter<String>],
        in source: String
    ) -> (String, [SourceSegment]) {
        return (
            removeNonSql(stmt, in: source),
            segment(stmt, parameters: parameters, source: source)
        )
    }
    
    mutating func removeNonSql<S: StmtSyntax>(_ stmt: S, in source: String) -> String {
        let rangesToRemove = stmt.accept(visitor: &self)
        
        guard !rangesToRemove.isEmpty else { return "\(source[stmt.location.range]);" }
        
        var final = ""
        var start = stmt.location.lowerBound
        
        // Remove in reverse so the range start does not change.
        for range in rangesToRemove.sorted(by: { $0.lowerBound < $1.lowerBound }) {
            final.append(contentsOf: source[start..<range.lowerBound])
            start = range.upperBound
        }
        
        if start < stmt.location.upperBound {
            final.append(contentsOf: source[start..<stmt.location.upperBound])
        }
        
        return final.trimmingCharacters(in: .whitespaces)
    }
    
    /// Splits the source into segments where each segment is either
    /// just text or a spot where a list/row parameter must have its
    /// bind parameter indices inserted at runtime.
    ///
    /// SQLite does not support by default passing in a list as a parameter
    /// for statements like `bar IN :elements`.
    /// The above example will need to get rewritten as `bar IN (?, ?, ?)`
    /// having a `?` for each element in the list.
    func segment<S: StmtSyntax>(
        _ stmt: S,
        parameters: [Parameter<String>],
        source: String
    ) -> [SourceSegment] {
        // All row parameters in order from start to finish associated to the
        // parameter they appeared from.
        let rowRanges: [(Range<Substring.Index>, Parameter<String>)] = parameters
            .compactMap { param -> [(Range<Substring.Index>, Parameter<String>)]? in
                guard case .row = param.type else { return nil }
                return param.locations.map { ($0.range, param) }
            }
            .flatMap(\.self)
            .sorted { $0.0.lowerBound < $1.0.lowerBound }
        
        guard !rowRanges.isEmpty else {
            return [.text(source[stmt.location.range])]
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
        var startIndex = stmt.location.lowerBound
        
        for (rowRange, param) in rowRanges {
            let textRange = startIndex..<rowRange.lowerBound
            let text = source[textRange]
            segments.append(.text(text))
            segments.append(.rowParam(param))
            startIndex = rowRange.upperBound
        }
        
        // If the last range wasnt to the end of the string
        // then make sure to append the rest
        if startIndex < stmt.location.upperBound {
            let textRange = startIndex..<stmt.location.upperBound
            let text = source[textRange]
            segments.append(.text(text))
        }
        
        return segments
    }
}

extension Rewriter: StmtSyntaxVisitor {
    func visit(_ stmt: CreateTableStmtSyntax) -> [Range<Substring.Index>] {
        switch stmt.kind {
        case let .columns(columns, _, _):
            return columns.values.compactMap { $0.type.alias?.location.range }
        case .select:
            return []
        }
    }
    
    func visit(_ stmt: AlterTableStmtSyntax) -> [Range<Substring.Index>] {
        return switch stmt.kind {
        case let .addColumn(c): c.type.alias.map { [$0.name.location.range] } ?? []
        default: []
        }
    }
    
    func visit(_ stmt: EmptyStmtSyntax) -> [Range<Substring.Index>] { [] }
    
    func visit(_ stmt: SelectStmtSyntax) -> [Range<Substring.Index>] { [] }
    
    func visit(_ stmt: InsertStmtSyntax) -> [Range<Substring.Index>] { [] }
    
    func visit(_ stmt: UpdateStmtSyntax) -> [Range<Substring.Index>] { [] }
    
    func visit(_ stmt: DeleteStmtSyntax) -> [Range<Substring.Index>] { [] }
    
    func visit(_ stmt: QueryDefinitionStmtSyntax) -> [Range<Substring.Index>] {
        // Remove the `DEFINE QUERY name AS`
        return [stmt.location.lowerBound..<stmt.statement.location.lowerBound]
    }
    
    func visit(_ stmt: PragmaStmtSyntax) -> [Range<Substring.Index>] { [] }
    
    func visit(_ stmt: DropTableStmtSyntax) -> [Range<Substring.Index>] { [] }
    
    func visit(_ stmt: CreateIndexStmtSyntax) -> [Range<Substring.Index>] { [] }
    
    func visit(_ stmt: DropIndexStmtSyntax) -> [Range<Substring.Index>] { [] }
    
    func visit(_ stmt: ReindexStmtSyntax) -> [Range<Substring.Index>] { [] }
    
    func visit(_ stmt: CreateViewStmtSyntax) -> [Range<Substring.Index>] { [] }
    
    func visit(_ stmt: DropViewStmtSyntax) -> [Range<Substring.Index>] { [] }
    
    func visit(_ stmt: CreateVirtualTableStmtSyntax) -> [Range<Substring.Index>] {
        return stmt.arguments.flatMap { argument -> [Range<Substring.Index>] in
            guard case let .fts5Column(_, typeName, notNull, _) = argument else { return [] }
            if let typeName, let notNull { return [typeName.location.range, notNull.range] }
            if let typeName { return [typeName.location.range] }
            if let notNull { return [notNull.range] }
            return []
        }
    }
    
    func visit(_ stmt: CreateTriggerStmtSyntax) -> [Range<Substring.Index>] { [] }
    
    func visit(_ stmt: DropTriggerStmtSyntax) -> [Range<Substring.Index>] { [] }
    
    func visit(_ stmt: BeginStmtSyntax) -> [Range<Substring.Index>] { [] }
    
    func visit(_ stmt: CommitStmtSyntax) -> [Range<Substring.Index>] { [] }
    
    func visit(_ stmt: RollbackStmtSyntax) -> [Range<Substring.Index>] { [] }
    
    func visit(_ stmt: SavepointStmtSyntax) -> [Range<Substring.Index>] { [] }
    
    func visit(_ stmt: ReleaseStmtSyntax) -> [Range<Substring.Index>] { [] }
    
    func visit(_ stmt: VacuumStmtSyntax) -> [Range<Substring.Index>] { [] }
}
