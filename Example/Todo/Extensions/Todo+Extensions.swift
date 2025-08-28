//
//  Todo+Extensions.swift
//  Todo
//
//  Created by Wes Wickwire on 8/27/25.
//

import Foundation

extension Todo {
    static func mock(
        id: Int = Int.random(in: 0..<Int.max),
        name: String = "Walk Dog",
        created: Date = .now,
        completed: Date? = nil
    ) -> Todo {
        Todo(
            id: id,
            name: name,
            created: created,
            completed: completed,
            isCompleted: completed != nil
        )
    }
}
