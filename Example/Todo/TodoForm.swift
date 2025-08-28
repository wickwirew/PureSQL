//
//  TodoForm.swift
//  Todo
//
//  Created by Wes Wickwire on 8/27/25.
//

import SwiftUI

struct TodoForm: View {
    @State var model: TodoFormModel
    @FocusState var isFocused: Bool
    
    var body: some View {
        TextField("What to do...", text: $model.name, axis: .vertical)
            .padding()
            .frame(maxHeight: .infinity, alignment: .top)
            .navigationBarTitleDisplayMode(.inline)
            .navigationTitle(model.title)
            .focused($isFocused, equals: true)
            .onAppear {
                isFocused = true
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        Task {
                            await model.save()
                        }
                    }
                }
                
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel", role: .cancel) {
                        model.cancel()
                    }
                }
            }
    }
}

#Preview {
    NavigationStack {
        TodoForm(
            model: TodoFormModel(
                mode: .update(.mock()),
                todoQueries: TodoQueriesNoop(),
                complete: {}
            )
        )
    }
}

