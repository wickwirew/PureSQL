//
//  TodoList.swift
//  Todo
//
//  Created by Wes Wickwire on 8/27/25.
//

import SwiftUI
import Otter

struct TodoList: View {
    @State var model: TodoListModel
    
    var body: some View {
        List(model.todos) { todo in
            Button {
                model.edit(todo: todo)
            } label: {
                cell(for: todo)
            }
        }
        .listStyle(.plain)
        .navigationTitle("Todos")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await model.load()
        }
        .sheet(item: $model.formModel) { formModel in
            NavigationStack {
                TodoForm(model: formModel)
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("New", systemImage: "plus") {
                    model.createTodo()
                }
            }
        }
    }
    
    private func cell(for todo: Todo) -> some View {
        HStack {
            Text(todo.name)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            Button {
                Task {
                    await model.toggle(todo: todo)
                }
            } label: {
                Image(systemName: todo.isCompleted ? "checkmark.square.fill" : "square")
                    .foregroundStyle(todo.isCompleted ? .blue : .secondary)
            }
            .contentTransition(.symbolEffect(.automatic, options: .speed(1.75)))
            .sensoryFeedback(.selection, trigger: todo.isCompleted)
        }
    }
}

#Preview {
    NavigationStack {
        TodoList(
            model: TodoListModel(
                todoQueries: .noop(
                    selectTodos: Queries.Just([
                        .mock(name: "Walk Dog"),
                        .mock(name: "Clean Kitchen", completed: .now),
                        .mock(name: "Pull Weeds"),
                    ])
                )
            )
        )
    }
}
