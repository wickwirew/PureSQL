//
//  TodoFormModel.swift
//  Todo
//
//  Created by Wes Wickwire on 8/27/25.
//

import Foundation

@Observable
@MainActor
final class TodoFormModel: Identifiable {
    let mode: Mode
    let complete: () -> Void
    let todoQueries: TodoQueries
    
    var name = ""
    var error: Error?
    
    enum Mode {
        case create
        case update(Todo)
    }
    
    init(
        mode: Mode,
        todoQueries: TodoQueries,
        complete: @escaping () -> Void
    ) {
        self.mode = mode
        self.todoQueries = todoQueries
        self.complete = complete
    }
    
    var title: String {
        switch mode {
        case .create: "New Todo"
        case .update: "Edit Todo"
        }
    }
    
    func save() async {
        do {
            switch mode {
            case .create:
                _ = try await todoQueries.insertTodo.execute(name)
            case .update(let todo):
                try await todoQueries.updateTodo.execute(name: name, id: todo.id)
            }
            
            complete()
        } catch {
            self.error = error
        }
    }
    
    func cancel() {
        complete()
    }
}
