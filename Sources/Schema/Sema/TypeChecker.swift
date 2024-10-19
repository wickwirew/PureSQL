//
//  TypeChecker.swift
//
//
//  Created by Wes Wickwire on 10/19/24.
//

struct TyVarSupplier {
    private var n = 0
    
    mutating func next() -> TyVar {
        defer { n += 1 }
        return TyVar(n: n)
    }
}

struct TyVar: Hashable, CustomStringConvertible {
    let n: Int
    
    init(n: Int) {
        self.n = n
    }
    
    var description: String {
        return "τ\(n)"
    }
}

enum SolutionTy {
    case tyVar(TyVar)
    case ty(TypeName)
    case someInteger
    case someFloat
    case someText
}

typealias Substitution = [TyVar: SolutionTy]

struct TypeChecker {
    private var supply = TyVarSupplier()
}

extension TypeChecker: ExprVisitor {
    typealias Output = (SolutionTy, Substitution)
    
    func visit(_ expr: Literal) throws -> (SolutionTy, Substitution) {
        fatalError()
//        return switch expr {
//        case .numeric(_, let isInt): isInt ? (.someInteger, [:]) : (.someFloat, [:])
//        case .string: (.someText, [:])
//        case .blob: (.ty(.blob), [:])
//        case .null:
//            <#code#>
//        case .true:
//            <#code#>
//        case .false:
//            <#code#>
//        case .currentTime:
//            <#code#>
//        case .currentDate:
//            <#code#>
//        case .currentTimestamp:
//            <#code#>
//        }
    }
    
    func visit(_ expr: BindParameter) throws -> (SolutionTy, Substitution) {
        fatalError()
    }
    
    func visit(_ expr: ColumnExpr) throws -> (SolutionTy, Substitution) {
        fatalError()
    }
    
    func visit(_ expr: PrefixExpr) throws -> (SolutionTy, Substitution) {
        fatalError()
    }
    
    func visit(_ expr: InfixExpr) throws -> (SolutionTy, Substitution) {
        fatalError()
    }
    
    func visit(_ expr: PostfixExpr) throws -> (SolutionTy, Substitution) {
        fatalError()
    }
    
    func visit(_ expr: BetweenExpr) throws -> (SolutionTy, Substitution) {
        fatalError()
    }
    
    func visit(_ expr: FunctionExpr) throws -> (SolutionTy, Substitution) {
        fatalError()
    }
    
    func visit(_ expr: CastExpr) throws -> (SolutionTy, Substitution) {
        fatalError()
    }
    
    func visit(_ expr: Expression) throws -> (SolutionTy, Substitution) {
        fatalError()
    }
    
    func visit(_ expr: CaseWhenThen) throws -> (SolutionTy, Substitution) {
        fatalError()
    }
}
