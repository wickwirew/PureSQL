//
//  SourceLocation.swift
//  Feather
//
//  Created by Wes Wickwire on 5/3/25.
//

public struct SourceLocation: Hashable, Sendable {
    public var range: Range<Substring.Index>
    
    public static let empty = SourceLocation(range: "".startIndex ..< "".endIndex)
    
    public init(range: Range<Substring.Index>) {
        self.range = range
    }
    
    public var lowerBound: Substring.Index {
        return range.lowerBound
    }
    
    public var upperBound: Substring.Index {
        return range.upperBound
    }
    
    public func spanning(_ after: SourceLocation) -> SourceLocation {
        return SourceLocation(range: range.lowerBound ..< after.range.upperBound)
    }
    
    public func upTo(_ next: SourceLocation) -> SourceLocation {
        return SourceLocation(range: range.lowerBound ..< next.range.lowerBound)
    }
    
    public func with(upperbound: Substring.Index) -> SourceLocation {
        return SourceLocation(range: range.lowerBound ..< upperbound)
    }
}

extension String {
    public subscript(_ location: SourceLocation) -> Substring {
        return self[location.range]
    }
}
