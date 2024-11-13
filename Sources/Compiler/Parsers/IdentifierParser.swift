//
//  IdentifierParser.swift
//
//
//  Created by Wes Wickwire on 10/9/24.
//

/// Parses a symbol, this can be a column name or any sort of non keyword
struct IdentifierParser: Parser, Sendable {
    func parse(state: inout ParserState) throws -> IdentifierSyntax {
        let token = try state.take()
        
        guard case let .symbol(symbol) = token.kind else {
            throw ParsingError.expectedSymbol(at: token.range)
        }
        
        return IdentifierSyntax(value: symbol, range: token.range)
    }
}

//extension IdentifierSyntax: Parsable {
//    static let parser = IdentifierParser()
//}
//
//
//typealias SyntaxID = Int
//
//struct IdSyntax: Syntax {
//    func accept<V>(visitor: V) where V : Syntax {
//        
//    }
//}
//
//protocol SyntaxVisitor {
//    func visit(syntax: IdSyntax)
//}
//
//protocol Syntax {
//    func accept<V: Syntax>(visitor: V)
//}
//
//struct SyntaxData {
//    let range: Range<Substring.Index>
//}
//
//struct
//
//struct AST: ~Copyable {
//    private var storage: [(any Syntax, SyntaxData)] = []
//    
//    mutating func insert<S: Syntax>(_ syntax: S, with data: SyntaxData) -> SyntaxID {
//        let loc = storage.count
//        storage.append(syntax)
//        return loc
//    }
//}
