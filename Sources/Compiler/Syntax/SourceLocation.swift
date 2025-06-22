//
//  SourceLocation.swift
//  Otter
//
//  Created by Wes Wickwire on 5/3/25.
//

public struct SourceLocation: Hashable, Sendable {
    public var range: Range<Substring.Index>
    public let line: Int
    public let column: Int
    
    public static let empty = SourceLocation(
        range: "".startIndex ..< "".endIndex,
        line: 0,
        column: 0
    )
    
    public var lowerBound: Substring.Index {
        return range.lowerBound
    }
    
    public var upperBound: Substring.Index {
        return range.upperBound
    }
    
    public func spanning(_ after: SourceLocation) -> SourceLocation {
        return SourceLocation(
            range: range.lowerBound ..< after.range.upperBound,
            line: line,
            column: column
        )
    }
    
    public func upTo(_ next: SourceLocation) -> SourceLocation {
        return SourceLocation(
            range: range.lowerBound ..< next.range.lowerBound,
            line: line,
            column: column
        )
    }
    
    public func with(upperbound: Substring.Index) -> SourceLocation {
        return SourceLocation(
            range: range.lowerBound ..< upperbound,
            line: line,
            column: column
        )
    }
}

public extension String {
    subscript(_ location: SourceLocation) -> Substring {
        return self[location.range]
    }
}
