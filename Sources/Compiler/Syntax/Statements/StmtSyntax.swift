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
    mutating func visit(_ stmt: borrowing CreateTableStmtSyntax) -> StmtOutput
    mutating func visit(_ stmt: borrowing AlterTableStmtSyntax) -> StmtOutput
    mutating func visit(_ stmt: borrowing EmptyStmtSyntax) -> StmtOutput
    mutating func visit(_ stmt: borrowing SelectStmtSyntax) -> StmtOutput
    mutating func visit(_ stmt: borrowing InsertStmtSyntax) -> StmtOutput
    mutating func visit(_ stmt: borrowing UpdateStmtSyntax) -> StmtOutput
    mutating func visit(_ stmt: borrowing DropTableStmtSyntax) -> StmtOutput
    mutating func visit(_ stmt: borrowing DeleteStmtSyntax) -> StmtOutput
    mutating func visit(_ stmt: borrowing QueryDefinitionStmtSyntax) -> StmtOutput
    mutating func visit(_ stmt: borrowing PragmaStmtSyntax) -> StmtOutput
    mutating func visit(_ stmt: borrowing CreateIndexStmtSyntax) -> StmtOutput
    mutating func visit(_ stmt: borrowing DropIndexStmtSyntax) -> StmtOutput
    mutating func visit(_ stmt: borrowing ReindexStmtSyntax) -> StmtOutput
    mutating func visit(_ stmt: borrowing CreateViewStmtSyntax) -> StmtOutput
    mutating func visit(_ stmt: borrowing DropViewStmtSyntax) -> StmtOutput
    mutating func visit(_ stmt: borrowing CreateVirtualTableStmtSyntax) -> StmtOutput
    mutating func visit(_ stmt: borrowing CreateTriggerStmtSyntax) -> StmtOutput
    mutating func visit(_ stmt: borrowing DropTriggerStmtSyntax) -> StmtOutput
}
