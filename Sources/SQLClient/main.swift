import SQL

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


@Database
struct DB: Database {
    static var queries: [String: String] {
        return [
            "User": "SELECT * FROM user WHERE id = ?",
            
            "Pet": "SELECT * FROM pet WHERE id = ?",
            
            "UserWithPet": """
            SELECT user.fullName, pet.name AS petName
            FROM user
            JOIN pet ON pet.ownerId = user.id
            WHERE user.id = ?;
            """
        ]
    }

    static var migrations: [String] {
        return [
            """
            CREATE TABLE user (
                id INTEGER PRIMARY KEY,
                firstName TEXT NOT NULL,
                lastName TEXT NOT NULL,
                age INTEGER,
                fullName TEXT NOT NULL GENERATED ALWAYS AS (firstName || ' ' || lastName) VIRTUAL
            );
            """,
            
            """
            CREATE TABLE pet (
                id INTEGER PRIMARY KEY,
                ownerId INTEGER REFERENCES user,
                name TEXT NOT NULL
            );
            """
        ]
    }
}
