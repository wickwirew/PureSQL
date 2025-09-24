//
//  Collection+Extensions.swift
//  PureSQL
//
//  Created by Wes Wickwire on 6/8/25.
//

extension RangeReplaceableCollection where Self: ExpressibleByArrayLiteral, Element: Hashable {
    /// Will return a new collection removing any duplicate items.
    /// While retaining the original order.
    func distinct() -> Self {
        // Cannot have duplicates if there is 1 or less elements.
        guard count > 1 else { return self }
        
        // Technically we could skip the set creation for when the count
        // is 2 since there is only 1 possible value if there are dupelicates
        // but it is not worth it.
        var seen: Set<Element> = []
        var result: Self = []
        
        // Given that there are probably duplicates, the require capacity
        // is probably lower so we can start out at half
        let expectedCapacity = count / 2
        
        // Anything less than 2 isnt worth doing since the first append
        // will bump the capacity to 2.
        if expectedCapacity >= 2 {
            result.reserveCapacity(expectedCapacity)
        }
        
        for element in self {
            guard !seen.contains(element) else { continue }
            seen.insert(element)
            result.append(element)
        }
        
        return result
    }
}
