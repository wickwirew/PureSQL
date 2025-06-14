//
//  StmtSyntax.swift
//
//
//  Created by Wes Wickwire on 10/8/24.
//

import OrderedCollections

protocol StmtSyntax: Syntax {
    func accept<V: StmtSyntaxVisitor>(visitor: inout V) -> V.StmtOutput
}

protocol StmtSyntaxVisitor {
    associatedtype StmtOutput
    mutating func visit(_ stmt: CreateTableStmtSyntax) -> StmtOutput
    mutating func visit(_ stmt: AlterTableStmtSyntax) -> StmtOutput
    mutating func visit(_ stmt: EmptyStmtSyntax) -> StmtOutput
    mutating func visit(_ stmt: SelectStmtSyntax) -> StmtOutput
    mutating func visit(_ stmt: InsertStmtSyntax) -> StmtOutput
    mutating func visit(_ stmt: UpdateStmtSyntax) -> StmtOutput
    mutating func visit(_ stmt: DropTableStmtSyntax) -> StmtOutput
    mutating func visit(_ stmt: DeleteStmtSyntax) -> StmtOutput
    mutating func visit(_ stmt: QueryDefinitionStmtSyntax) -> StmtOutput
    mutating func visit(_ stmt: PragmaStmtSyntax) -> StmtOutput
    mutating func visit(_ stmt: CreateIndexStmtSyntax) -> StmtOutput
    mutating func visit(_ stmt: DropIndexStmtSyntax) -> StmtOutput
    mutating func visit(_ stmt: ReindexStmtSyntax) -> StmtOutput
    mutating func visit(_ stmt: CreateViewStmtSyntax) -> StmtOutput
    mutating func visit(_ stmt: DropViewStmtSyntax) -> StmtOutput
    mutating func visit(_ stmt: CreateVirtualTableStmtSyntax) -> StmtOutput
    mutating func visit(_ stmt: CreateTriggerStmtSyntax) -> StmtOutput
    mutating func visit(_ stmt: DropTriggerStmtSyntax) -> StmtOutput
    mutating func visit(_ stmt: BeginStmtSyntax) -> StmtOutput
    mutating func visit(_ stmt: CommitStmtSyntax) -> StmtOutput
    mutating func visit(_ stmt: RollbackStmtSyntax) -> StmtOutput
    mutating func visit(_ stmt: SavepointStmtSyntax) -> StmtOutput
    mutating func visit(_ stmt: ReleaseStmtSyntax) -> StmtOutput
    mutating func visit(_ stmt: VacuumStmtSyntax) -> StmtOutput
}
