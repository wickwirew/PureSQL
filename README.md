<p align="center">
    <picture align="center">
        <source media="(prefers-color-scheme: dark)" srcset="./PureSQL~dark.png">
        <source media="(prefers-color-scheme: light)" srcset="./PureSQL.png">
        <img alt="PureSQL" src="./PureSQL.png" width=40% height=40%>
    </picture>
</p>

<p align="center">
    <strong>
        A SQLite compiler, static analyzer and code generator for Swift ❤️
    </strong>
</p>

# Overview
PureSQL is a pure Swift SQL compiler that allows developers to simply write plain SQL with compile time safety.
If your database schema changes, you will get compile time errors for the places that need to be fixed.
It doesn't just generate the code to talk to SQLite, but rather your entire data layer in a testable
flexible manner. No more writing mocks or wrappers. Just pass in the query.

- [Installation](#installation)
- [Macros](#or-use-the-swift-macro)
- [Queries](#queries)
- [Types](#types)
- [Dependency Injection](#dependency-injection)

## Basic Primer

As a quick intro, here is a basic example. First, in SQL we will create our migrations and our first query.
```sql
-- Located in Migrations/1.sql
CREATE TABLE todo (
  id INTEGER,
  name TEXT NOT NULL,
  completedOn INTEGER AS Date
)

-- Located in Queries/Todo.sql
selectTodos:
SELECT * FROM todo;
```

PureSQL will automatically generate all structs for the tables and queries providing the APIs below

```swift
// Open a connection to the database
let database = try DB(path: "...")

// Execute the query
let todos = try await database.todoQueries.selectTodos.execute()

for todo in todos {
  print(todo.id, todo.name, todo.completedOn)
}

// Easily observe any query as the database changes.
for try await todos in database.todoQueries.selectTodos.observe() {
  print("Got todos", todos)
}
```

PureSQL is built with testing in mind. Dependency injection is possible right out of the box.
No need to wrap your database in repositories. Just pass in the `any <Name>Query` and
you can pass in `Queries.Just`, `Queries.Fail` or even `Queries.Test` for call counts.
```swift
class ViewModel {
  let selectTodos: any SelectTodosQuery
}

let live = ViewModel(selectTodos: db.todoQueries.selectTodos)

let test = ViewModel(selectTodos: Queries.Just([Todo(...)]))
```

### Or Use the Swift Macro
PureSQL can even run within a Swift macro by adding the `@Database` macro to a `struct`.

```swift
@Database
struct DB {
    @Query("SELECT * FROM todo")
    var selectTodos: any SelectTodosQuery
    
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

> [!IMPORTANT]
> As of now it is not recommended for larger projects. There are quite a few limitations 
that won't scale well beyond a fairly simple schema and a handful of queries.

#### Anatomy of @Query
```swift
@Query(
    "SELECT * FROM foo WHERE id IN ?", // 1.
    inputName: "CustomInputName", // 2.
    outputName: "CustomOutputName" // 3.
)
var variableName: any MyQuery // 4.
```
1. The raw SQL to execute
2. Optionally supply a custom type name for the generated input type.
3. Optionally supply a custom type name for the generated output type.
4. The `variableName` can be anything and does not affect any of the generated code.

#### Current Limitations
* Since macros operate purely on the syntax, all queries must be within the `@Database` itself so it has access to the schema.
* All generated types will be nested under the `@Database` struct.
* Any diagnostics will be on the entire string rather than the part that actually failed.

# Installation
PureSQL supports Swift Package Manager. To install add the following to your `Package.swift` file.

> [!TIP]
> If don't want to read any of the README, here are some quick tips:
> * Use singular table names, it is the SQL standard.
> * Orgranize queries in files by usage, not by table.
> * Use `SELECT table.*` to embed the table structs within the results
> * Inject queries and avoid the repository pattern
> * Let SQL answer the questions about your data. Many queries are perfectly fine

```swift
let package = Package(
    [...]
    dependencies: [
        .package(url: "https://github.com/wickwirew/PureSQL.git", from: "...")
    ],
    targets: [
        .target(
            name: "MyProject",
            dependencies: ["PureSQL"],
            // ⚠️ Plugin is optional but suggested. Can just use the CLI if desired
            plugins: [.plugin(name: "PureSQLPlugin", package: "PureSQL")]
        ),
    ]
)
```

#### Xcode Project Plugin Setup
For projects using an `xcodeproj` to setup the plugin it can be enabled by selecting the target and going to `Build Phases > Run Build Tool Plug-ins` and adding it to the list by selecting the plus.

## Install CLI tool
You can install the CLI tool via homebrew by executing:
```
brew tap wickwirew/wickwirew
brew install puresql
```

Once the project has been added it is time to setup the queries and migrations folders. In the root of the project where you want everything to live, in terminal run the following command
```
puresql init
```

This will create an `puresql.yaml` configuration file. Here is where you can setup the project and define the directories of the migrations and queries and other project settings.

> [!TIP]
> Follow the SQL standard and use singular table names. This will stop table structs from being named plural

### Adding a New Migration
When a new migration is needed, you can simply add a new file with a number 1 higher than the previous. To automatically do this the cli tool can do it for you by running
```
puresql migrations add
```

> [!WARNING]
> Plugin requires a clean build any time a new `sql` file is added so the input file list can be updated.

#### Generating the Database - Without Plugin
Once you have your first migration in and the project setup you can now generate the database. In the same directory where `init` was run, you run the `gen` command.
```
puresql generate
```

This will compile and check all migrations and queries, then generate all Swift required to talk to the database.

# Opening a Connection
Once you have your database being generated, you can now open a connection to it. Each database will automatically have a few initializers at hand to choose from. Each are listed below. When the connection is opened, all migrations are run instantly.

All connections are automatically opened up in WAL journal mode, allowing asynchronous reads while writes are happening. And all connections will automatically handle all threading and scheduling of queries for you.

```swift
// Defaults to a connection pool of 5 connections
let database = try DB(path: "...")

// Opens the database in memory, useful for unit tests or previews
let database = try DB.inMemory()

// Or open up using the configuration.
var config = DatabaseConfig()
config.path = "" // if nil, it will be in memory
config.maxConnectionCount = 8
let database = try DB(config: config)

// All migrations are run on open, so it's good to use right away
```

# Queries
All queries will be stored in the `/Queries` directory. More than one query can go in each file. To get started, create a new file in the `/Queries` directory. The cli can do this automatically. In the same directory where `init` was run, execute
```
puresql queries add <some-name>
```

Open the file that was created in `/Queries`, it should be blank. Individual queries can be defined using the the following format. At the moment a single query can only have one statement.
```sql
fetchUsers:
SELECT * FROM user;

-- Or optionally supply either an input or output name
fetchUsers(input: InputName, output: OutputName):
SELECT * FROM user;
```

> [!TIP]
> Organize queries by usage, not by table.
> This will allow queries to be injected together

Each queries file will get it's own `Queries` types generated. To allow the queries defined in a file to be 
passed around and injected together. For example, if we have a `Library.sql` the following types will be generated:
```swift
// Protocol that defines all queries in the file
let queries: LibraryQueries = database.libraryQueries

// Queries that do not talk to a database and just return `nil` or `[]` via `Queries.Just`
let noopQueries: LibraryQueries = .noop()
```

For the `noop` queries, we can override any query optionally. Each query be default will return `nil` or an empty `[]`. To override a query you can set it in the initializer.
```swift
LibraryQueries.noop(getLibrary: Queries.Just([...]))
```

### Input and Output Types
PureSQL will, if needed, generate types for the inputs and outputs. If a type is a single primitive it will be mapped to the Swift equivalent.
```sql
-- Will return the User struct
fetchUsers:
SELECT * FROM user;

-- Will generate a type for the id and name
fetchUserIdAndNames:
SELECT id, name FROM user;
```

#### Embedding Table Structs
In the example above, since we selected all columns from a single table the query will return the `User` struct that was generated for the table. If additional columns are selected a new structure will be generated to match the selected columns. In the following example we will join in the `post` table to get a users post count.
```sql
fetchUsers:
SELECT user.*, COUNT(*) AS numberOfPosts
LEFT OUTER JOIN post ON post.userId = user.id
GROUP BY user.id;
```

The following `struct` would automatically be generated for the query. Since we used the syntax `user.*` it will embed the `User` struct instead of replicating it's columns. Any embeded table struct will also get a `@dynamicMemberLookup` method generated so it can be accessed directly like the other column values. This allows extensions on the table struct to work across many queries.
```swift
@dynamicMemberLookup
struct FetchUsersOutput {
    let user: User
    let numberOfPosts: Int

    subscript<Value>(dynamicMember dynamicMember: KeyPath<FetchUsersOutput, Value>) -> Value { ... }
}
```

### Inputs
When a query has multiple inputs it will have a struct generated for it's inputs similar to the output. Also, so the input struct does not have to be initialized every time, an extension will be created that takes each parameter individually, rather then the full type.
```sql
userPosts:
SELECT * FROM post WHERE userId = ? AND date BETWEEN ? AND ?;
```

Would generate the following Swift code

```swift
struct UserPostsInput {
    let userId: Int
    let dateLower: Date
    let dateUpper: Date
}

// Using the extension
let posts = try await database.userQueries.userPosts.execute(userId: id, dateLower: lower, dateUpper: upper)

// Or using the input type directly
let posts = try await database.userQueries.userPosts.execute(UserPostInput(...))
```

### Naming
The `FetchUsersOutput` name, while clear where it came from, is not too great if we want to store it in a view model or model within our app. Some queries we want to give it a better name that has more meaning. In the `DEFINE` statement we can specify a name for the inputs and outputs.
```sql
queryName(input: InputName, output: OutputName):
...
```

# Types
SQLite is a unique SQL database engine in that it is fairly lawless when it comes to typing. SQLite will allow you to create a column with an `INTEGER` and gladly insert a `TEXT` into it. It will even let you make up your own type names and it will take them. PureSQL will not allow this and tends to operate more strictly like the table option `STRICT`. Only the core types that SQLite recognizes are usable for the column type.
| SQLite  | Swift  |
|---------|--------|
| INTEGER | Int    |
| REAL    | Double |
| TEXT    | String |
| BLOB    | Data   |
| ANY     | SQLAny |

### Custom Types
While your column only can be one of the core SQLite types, what type that ends up as in Swift can be different. Using the `AS` keyword you can specify the Swift type to decode it to. Think of the column type as the storage type while the type in the `AS` will be the type actually in the interface.

Using the `AS` keyword you can specify the type to use in `Swift`
```sql
-- UUID stored as a string
TEXT AS UUID
-- UUID stored as it's raw bytes
BLOB AS UUID
-- If the type has `.` in it, put the name in quotes to escape it.
TEXT AS "Todo.ID"
```

## Dependency Injection
> TL;DR Avoid the repository pattern, inject queries.

PureSQL was written with application development in mind. One of the pain points when talking to a database is dependency injection. 
Normally this would mean wrapping your database calls in a repository or some other layer to keep the model layer testable without needing a database connection. 
This is all good but that means writing different protocols and mocks. When writing the protocol you need to decide whether to just make it `async` or maybe a `publisher`. 
Sometimes you need both... PureSQL solves these problems and was designed to have injection builtin.

At the core, PureSQL exposes one core type for injections which is `any Query<Input, Output>`. This acts as a wrapper, which knows nothing about the database that can passed into a model or view model. For example, if we have a query that takes in an `Int` and returns a `String` we can setup our view model like:
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
latestExpenses:
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

## FTS5
FTS5 is supported but has some additional requirements.
To generate usable structs PureSQL needs type information even though they not valid FTS arguments.
Specifying the type is **required** and an optional `NOT NULL` is allowed. These are not FTS5
arguments so they will be removed from the final migration.
```sql
CREATE VIRTUAL TABLE searchIndex USING fts5 (
    id INTEGER NOT NULL,
    text TEXT
);

SELECT * FROM searchIndex
WHERE text MATCH 'search terms'
ORDER BY rank;
```

## Upcoming Features
PureSQL is a young project and there are a lot of new features and functionality I want to add.
Below are some idea that I would love input on!
- LSP and vscode plugin
- Support for multiple statements in a single query
- Kotlin library/generation
  - Generating Kotlin would allow SQLite based apps to basically share their model/data layer
- User defined functions
  - SQLite supports custom functions which are a great way to share common logic amongst queries
- Queries with multiple statements
  - Would allow for easier loading of more complex models that have many joins
  - Want to allow other queries to be called from within the body to help centralize logic.
- Postgres support for server side swift

## Contributions
Contributions are welcome and encouraged! Feel free to make a PR or open an issue. If the change is large please open an issue first to make sure the change is desired.
