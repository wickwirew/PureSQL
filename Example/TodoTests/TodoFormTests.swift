//
//  TodoFormTests.swift
//  TodoTests
//
//  Created by Wes Wickwire on 8/27/25.
//

import Testing
import Otter

@testable import Todo

@MainActor
@Suite
struct TodoFormTests {
    @Test func createInsertsTodo() async {
        let insertTodo = Queries.Test<String, Todo.ID>(0)
        
        let model = TodoFormModel(
            mode: .create,
            todoQueries: TodoQueriesNoop(insertTodo: insertTodo),
            complete: {}
        )
        
        await model.save()
        
        #expect(insertTodo.executeCallCount == 1)
    }
    
    @Test func updateUpdatesTodo() async {
        let updateTodo = Queries.Test<UpdateTodoInput, ()>()

        let model = TodoFormModel(
            mode: .update(.mock()),
            todoQueries: TodoQueriesNoop(updateTodo: updateTodo),
            complete: {}
        )
        
        await model.save()
        
        #expect(updateTodo.executeCallCount == 1)
    }
}
