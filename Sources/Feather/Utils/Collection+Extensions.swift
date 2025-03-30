//
//  Collection+Extensions.swift
//  Feather
//
//  Created by Wes Wickwire on 3/4/25.
//

extension Collection {
    public var sqlQuestionMarks: String {
        return (0..<count).map { _ in "?" }.joined(separator: ",")
    }
}
