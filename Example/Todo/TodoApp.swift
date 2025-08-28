//
//  TodoApp.swift
//  Todo
//
//  Created by Wes Wickwire on 8/27/25.
//

import SwiftUI

@main
struct TodoApp: App {
    let db = try! DB()
    
    var body: some Scene {
        WindowGroup {
            NavigationStack {
                TodoList(model: TodoListModel(todoQueries: db.todoQueries))
            }
        }
    }
}
