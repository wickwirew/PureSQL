<picture>
    <source media="(prefers-color-scheme: dark)" srcset="https://github.com/wickwirew/Feather/blob/main/Otter~dark.png?raw=true">
    <source media="(prefers-color-scheme: light)" srcset="https://github.com/wickwirew/Feather/blob/main/Otter.png?raw=true">
    <p align="center">
      <img alt="Otter" src="https://github.com/wickwirew/Feather/blob/main/Otter.png?raw=true" width=33% height=33%>
    </p>
</picture>

<p align="center">
  A fast, lightweight SQLite library for Swift
</p>

## Overview
Otter generates type safe code from raw plain SQL.

## Basic Usage
As a primer here is a quick example. Below is some SQL. The first part is in the `/Migrations` directory. This is where you can create and modify your schema. The second part is in the `/Queries` directory.
```sql
-- Located in Migrations/1.sql
CREATE TABLE todo (
  id INTEGER,
  name TEXT NOT NULL,
  completedOn INTEGER
)

-- Located in Queries/Todo.sql
DEFINE QUERY selectTodos AS
SELECT * FROM todo;
```
Would generate the following Swift code
```swift
let db = DB()
let todos = try await db.selectTodos.execute()

for todo in todos {
  print(todo.id, todo.name, todo.completedOn)
}

for try await todos in db.selectTodos.observe() {
  print("Got todos", todos)
}
```

## Dependency Injection
> TLDR; Avoid the repository pattern, inject queries.

Otter was written with application development in mind. One of the common walls when talking to a database is dependecy injection. 
Normally this would mean wrapping your database calls in a repository or some other layer to keep the model layer testable without needing a database connection. 
This is all good but that means writing different protocols and mocks. When writing the protocol you need to decide whether to just make it `async` or maybe a `publisher`. 
Sometimes you need both... Otter solves these problems and was designed to have injection builtin.

At the core, Otter exposes one core type for injections which is `any Query<Input, Output>`. This acts as a wrapper, which knows nothing about the database that can passed into a model or view model. For example, if we have a query that takes in an `Int` and returns a `String` we can setup our view model like:
```swift
class ViewModel {
  let fetchString: any Query<Int, String>
}
```

Then in your live application code that will actually ship to users you can pass in your database query
```swift
let viewModel = ViewModel(fetchString: database.fetchString)
```

In unit tests or previews where you don't want a database you can pass a `Just` or a `Fail`
```swift
let viewModel = ViewModel(fetchString: Queries.Just("Just a string, no database needed 😎"))

// Will throw the `MockError` any time the query is executed
let alwaysFails = ViewModel(fetchString: Queries.Fail(MockError()))
```

#### Injecting Type Aliases
The example above is nice but doesn't really represent the common use case. 
Most of the time we don't just have a query that has an input and output of simple builtins. 
They can be larger generated structs which can be a lot to type. To fix this typealiases are
generated for a query to give them a simple readable name. For example
```sql
DEFINE QUERY latestExpenses AS
SELECT id, title, amount FROM expense
WHERE date BETWEEN ? AND ?;
```
Would generate the following `typealias` for injection
```swift
class ViewModel {
  // Equivalent to `any Query<LatestExpensesInput, LatestExpensesOutput>`
  let query: any LatestExpensesQuery
}
```
