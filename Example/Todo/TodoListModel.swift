//
//  TodoListModel.swift
//  Todo
//
//  Created by Wes Wickwire on 8/27/25.
//

import Foundation

@Observable
@MainActor
final class TodoListModel {
    let todoQueries: TodoQueries
    
    var todos: [Todo] = []
    var error: Error?
    var formModel: TodoFormModel?
    
    init(todoQueries: TodoQueries) {
        self.todoQueries = todoQueries
    }
    
    func load() async {
        do {
            for try await todos in todoQueries.selectTodos.observe() {
                self.todos = todos
            }
        } catch {
            self.error = error
        }
    }
    
    func toggle(todo: Todo) async {
        do {
            try await todoQueries.toggleTodo.execute(todo.id)
        } catch {
            self.error = error
        }
    }
    
    func createTodo() {
        formModel = TodoFormModel(
            mode: .create,
            todoQueries: todoQueries
        ) { [weak self] in
            self?.formModel = nil
        }
    }
    
    func edit(todo: Todo) {
        formModel = TodoFormModel(
            mode: .update(todo),
            todoQueries: todoQueries
        ) { [weak self] in
            self?.formModel = nil
        }
    }
}
