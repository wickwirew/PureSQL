//
//  Collection+Extensions.swift
//  Otter
//
//  Created by Wes Wickwire on 3/4/25.
//

public extension Collection {
    var sqlQuestionMarks: String {
        return (0..<count).map { _ in "?" }.joined(separator: ",")
    }
}
