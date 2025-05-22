<picture>
    <source media="(prefers-color-scheme: dark)" srcset="https://github.com/wickwirew/Feather/blob/main/Otter~dark.png?raw=true">
    <source media="(prefers-color-scheme: light)" srcset="https://github.com/wickwirew/Feather/blob/main/Otter.png?raw=true">
    <p align="center">
      <img alt="Otter" src="https://github.com/wickwirew/Feather/blob/main/Otter.png?raw=true" width=40% height=40%>
    </p>
</picture>

<p align="center">
    <strong>
        A SQLite compiler, static analyzer and code generator for Swift ❤️
    </strong>
</p>

## Overview
Otter is a pure Swift SQL compiler that allow developers to write plain comile time safe SQL.

## Basic Usage
As a primer here is a quick example. First, in SQL we will create our migrations and our first query.
```sql
-- Located in Migrations/1.sql
CREATE TABLE todo (
  id INTEGER,
  name TEXT NOT NULL,
  completedOn INTEGER AS Date
)

-- Located in Queries/Todo/Todo.sql
DEFINE QUERY selectTodos AS
SELECT * FROM todo;
```

Otter will automatically generate all structs for the tables and queries providing the APIs below

```swift
// Open a connection to the database
let database = try DB(path: "...")

// Execute the query
let todos = try await database.todoQueries.selectTodos.execute()

// The `Todo` struct is automatically generated for the table
// meaning your schema and swift code will never get out of sync
for todo in todos {
  print(todo.id, todo.name, todo.completedOn)
}

// Easily observe any query as the database changes.
for try await todos in database.todoQueries.selectTodos.observe() {
  print("Got todos", todos)
}
```

### Or Use the Swift Macro
Otter can even run within a Swift macro by adding the `@Database` macro to a `struct`.

> As of now it is not recommended for larger projects. There are quite a few limitations 
that won't scale well beyond a fairly simple schema and a handfull of queries. ⚠️

```swift
@Database
struct DB {
    @Query("SELECT * FROM foo")
    var selectFooQuery: SelectFooDatabaseQuery
    
    static var migrations: [String] {
        return [
            """
            CREATE TABLE todo (
              id INTEGER,
              name TEXT NOT NULL,
              completedOn INTEGER AS Date
            )
            """
        ]
    }
}

func main() async throws {
    let database = try DB(path: "...")
    let todos = try await database.selectTodos.execute()

    for todo in todos {
      print(todo.id, todo.name, todo.completedOn)
    }
}
```

#### Current Limitations
* Since macros operate purely on the syntax, all queries must be within the `@Database` itself so it has access to the schema.
* All generated types will be nested under the `@Database` struct.
* All `@Query` definitions must define their type as the generated `typealias` by the `@Database` macro.
* Any diagnostics will be on the entire string rather than the part that actually failed.

## Opening a Connection
Each database will automatically have a few initializers at hand to choose from. Each are listed below.
When the connection is opened, all migrations are run instantly.

All connections are automatically opened up in WAL journal mode, allowing asynchronous reads while writes are happening. And all connections will automatically handle all threading and scheduling of queries for you.

```swift
// Defaults to a connection pool of 5 connections
let database = try DB(path: "...")

// Opens the database in memory, useful for unit tests or previews
let database = try DB.inMemory()

// Or open up using the configuration.
var config = DatbaseConfig()
config.path = "" // if nil, it will be in memory
config.maxConnectionCount = 8
let database = try DB(config: config)
```

## Types
SQLite is a unique SQL database engine in that it is fairly lawless when it comes to typing. SQLite will allow you create a column with an `INTEGER` and gladly insert a `TEXT` into it. It will even let you make up your own type names and will take them. Otter only supports the core types/affinities SQLite recognizes:
```
INTEGER -> Int
REAL -> Double
TEXT -> String
BLOB -> Data
ANY -> SQLAny
```

> SQLite is the Javascript of SQL databases
> 
>    Richard Hipp, creator of SQLite

#### Aliasing & Custom Types
SQLite's core affinity types are few, but with aliasing types we can represent more complex types in Swift like `Date` or `UUID`.

Using the `AS` keyword you can specify the type to use in `Swift`
```sql
TEXT as UUID

-- If the type has `.` in it, put the name in quotes to escape it.
TEXT as "Todo.ID"
```

## Operators
The library ships with a few core operators. The operators allow you to perform transformations on queries inputs or output. Or even combine queries.

## Then
Then is used to combine two queries together. It will execute `self` first then the input query. Each query will be run within the same transaction.

```swift
func then<Next>(
    _ next: Next,
    nextInput: @Sendable @escaping (Input, Output) -> Next.Input
) -> Queries.Then<Self, Next>
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
