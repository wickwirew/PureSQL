//
//  Range+Extensions.swift
//  Feather
//
//  Created by Wes Wickwire on 2/15/25.
//

extension Range where Bound == Substring.Index {
    static let empty: Range<Substring.Index> = {
        let str: Substring = ""
        return str.startIndex..<str.endIndex
    }()
}
