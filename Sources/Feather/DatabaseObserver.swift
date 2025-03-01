//
//  Observation.swift
//  Feather
//
//  Created by Wes Wickwire on 2/26/25.
//

import SQLite3

struct DatabaseEvent: Sendable {
    let operation: Operation
    let databaseName: String?
    let tableName: String?
    let rowId: Int64
    
    enum Operation: Int32 {
        case insert = 18 // SQLITE_INSERT
        case delete = 9 // SQLITE_DELETE
        case update = 23 // SQLITE_UPDATE
    }
}

actor DatabaseObserver: @unchecked Sendable {
    private var observations: [Observation.Id: Observation] = [:]

    func observe() -> Observation {
        let observation = Observation()
        observations[observation.id] = observation
        return observation
    }
    
    func cancel(observation: Observation) {
        observations[observation.id] = nil
    }
    
    func receive(event: DatabaseEvent) {
        for observation in observations.values {
            observation.emit(event: event)
        }
    }
    
    nonisolated func installHooks(into connection: Connection) {
        sqlite3_update_hook(
            connection.sqliteConnection,
            { selfPointer, operation, dbName, tableName, rowId in
                let dbObserver = Unmanaged<DatabaseObserver>
                    .fromOpaque(selfPointer!)
                    .takeUnretainedValue()
                
                dbObserver.receiveSqliteUpdateHook(
                    operation: operation,
                    dbName: dbName,
                    tableName: tableName,
                    rowId: rowId
                )
            },
            Unmanaged.passUnretained(self).toOpaque()
        )
    }
    
    nonisolated func receiveSqliteUpdateHook(
        operation: Int32,
        dbName: UnsafePointer<CChar>?,
        tableName: UnsafePointer<CChar>?,
        rowId: Int64
    ) {
        guard let operation = DatabaseEvent.Operation(rawValue: operation) else {
            fatalError("Unknown operation: \(operation)")
        }
        
        let event = DatabaseEvent(
            operation: operation,
            databaseName: dbName.map(String.init(cString:)),
            tableName: tableName.map(String.init(cString:)),
            rowId: rowId
        )
        
        Task {
            await receive(event: event)
        }
    }
}

//extension Query {
//    func values(
//        with input: Input,
//        in pool: ConnectionPool
//    ) -> AsyncThrowingStream<Output, Error> {
//        
//        
//        return AsyncThrowingStream<Output, Error> { continuation in
//            let token = pool.observe {
//                
//            }
//            
//            continuation.onTermination = {
//                pool.cancel(observation: token)
//            }
//        }
//    }
//}

class Observation: Identifiable, AsyncSequence, @unchecked Sendable {
    private let stream: AsyncStream<DatabaseEvent>
    private let continuation: AsyncStream<DatabaseEvent>.Continuation
    
    struct Id: Hashable, Sendable {
        let rawValue: ObjectIdentifier
    }
    
    init() {
        (stream, continuation) = AsyncStream.makeStream()
    }
    
    var id: Id {
        return Id(rawValue: ObjectIdentifier(self))
    }
    
    func emit(event: DatabaseEvent) {
        continuation.yield(event)
    }
    
    func cancel() {
        continuation.finish()
    }

    func makeAsyncIterator() -> AsyncStream<DatabaseEvent>.Iterator {
        return stream.makeAsyncIterator()
    }
}

