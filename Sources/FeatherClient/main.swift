import Feather
import Foundation

let a = 17
let b = 25

//let result = #stringify("SELECT * FROM table")

//let user = Schema.User(
//    id: 1,
//    firstName: "Dennis",
//    lastName: "Reynolds",
//    age: 123
//)
//
//print("The user \(user)")

let url = Bundle.module.url(forResource: "example", withExtension: "db")!

//@Database
//struct DB: Database {
//    static var queries: [String: String] {
//        return [
//            "User": "SELECT * FROM user"
//        ]
//    }
//
//    static var migrations: [String] {
//        return [
//            "CREATE TABLE user(id INTEGER PRIMARY KEY, name TEXT NOT NULL)"
//        ]
//    }
//}
//
//let connection = try Connection(path: url.absoluteString)
//
//let users = try await DB.UserQuery()
//    .with(input: .init())
//    .execute(in: connection)
//
//for user in users {
//    print(user.id, user.name)
//}
