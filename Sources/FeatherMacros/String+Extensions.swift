//
//  String+Extensions.swift
//  Feather
//
//  Created by Wes Wickwire on 5/10/25.
//

extension String {
    /// Removes the "Query" at the end of the string if it exists
    func removingQuerySuffix() -> String {
        var copy = self
        
        if copy.hasSuffix("Query") {
            copy.removeSubrange(copy.index(copy.endIndex, offsetBy: -5)..<copy.endIndex)
        }
        
        return copy
    }
}
