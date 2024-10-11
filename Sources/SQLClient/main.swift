import SQL

let a = 17
let b = 25

//let result = #stringify("SELECT * FROM table")

#schema([
    "createTables": """
    CREATE TABLE user (
        id INT PRIMARY KEY AUTOINCREMENT,
        firstName TEXT,
        lastName TEXT,
        age INT NOT NULL
    )
    """,
    
    "addFavoriteColor": """
    ALTER TABLE user ADD COLUMN favoriteColor TEXT NOT NULL DEFAULT 'green'
    """,
    
    "createFart": """
    CREATE TABLE fart (
    id INT PRIMARY KEY,
    smell INT NOT NULL
    )
    """
])

//let user = Schema.User(
//    id: 1,
//    firstName: "Dennis",
//    lastName: "Reynolds",
//    age: 123
//)
//
//print("The user \(user)")
