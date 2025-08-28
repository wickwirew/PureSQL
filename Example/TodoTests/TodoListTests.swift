//
//  TodoListTests.swift
//  Todo
//
//  Created by Wes Wickwire on 8/27/25.
//

import Testing
import Otter

@testable import Todo

@MainActor
@Suite
struct TodoListTests {
    @Test func todosAreSetOnLoad() async {
        let todos: [Todo] = [.mock(), .mock()]
        let selectTodos = Queries.Test<(), [Todo]>(todos)
        let model = TodoListModel(todoQueries: TodoQueriesNoop(selectTodos: selectTodos))
        
        await model.load()
        
        #expect(todos == model.todos)
        #expect(selectTodos.observeCallCount == 1)
    }
    
    @Test func loadFailureSetsError() async {
        let model = TodoListModel(
            todoQueries: TodoQueriesNoop(
                // Queries.Fail always throws an error
                selectTodos: Queries.Fail()
            )
        )
        
        await model.load()
        
        #expect(model.error != nil)
    }
    
    @Test func toggleTodoUpdatesDB() async {
        let toggleTodo = Queries.Test<Todo.ID, ()>()
        let model = TodoListModel(todoQueries: TodoQueriesNoop(toggleTodo: toggleTodo))
        
        await model.toggle(todo: .mock())
        
        #expect(toggleTodo.executeCallCount == 1)
    }
}
