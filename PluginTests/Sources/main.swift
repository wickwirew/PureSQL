import PureSQL

let db = try DB.inMemory()

try await db.fooQueries.insertFoo.execute()
try await db.fooQueries.insertFoo.execute()
try await db.fooQueries.insertFoo.execute()

let foos = try await db.fooQueries.selectFoos.execute()

for foo in foos {
    print(foo.bar)
}
