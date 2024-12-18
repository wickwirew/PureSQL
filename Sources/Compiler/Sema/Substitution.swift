//
//  Substitution.swift
//  Feather
//
//  Created by Wes Wickwire on 12/17/24.
//

typealias Substitution = [TypeVariable: Ty]

extension Substitution {
    func merging(_ other: Substitution) -> Substitution {
        guard !other.isEmpty else { return self }
        return merging(other, uniquingKeysWith: { $1 })
    }
    
    func merging(_ a: Substitution, _ b: Substitution) -> Substitution {
        var output = self
        for (k, v) in a {
            output[k] = v
        }
        for (k, v) in b {
            output[k] = v
        }
        return output
    }
    
    func merging(_ a: Substitution, _ b: Substitution, _ c: Substitution) -> Substitution {
        var output = self
        for (k, v) in a {
            output[k] = v
        }
        for (k, v) in b {
            output[k] = v
        }
        for (k, v) in c {
            output[k] = v
        }
        return output
    }
    
    func merging(_ a: Substitution, _ b: Substitution, _ c: Substitution, _ d: Substitution) -> Substitution {
        var output = self
        for (k, v) in a {
            output[k] = v
        }
        for (k, v) in b {
            output[k] = v
        }
        for (k, v) in c {
            output[k] = v
        }
        for (k, v) in d {
            output[k] = v
        }
        return output
    }
    
    func merging(_ a: Substitution, _ b: Substitution, _ c: Substitution, _ d: Substitution, _ e: Substitution) -> Substitution {
        var output = self
        for (k, v) in a {
            output[k] = v
        }
        for (k, v) in b {
            output[k] = v
        }
        for (k, v) in c {
            output[k] = v
        }
        for (k, v) in d {
            output[k] = v
        }
        for (k, v) in e {
            output[k] = v
        }
        return output
    }
}
