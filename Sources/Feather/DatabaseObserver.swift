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
    private var subscribers: [ObjectIdentifier: any DatabaseSubscriber] = [:]

    func subscribe(subscriber: any DatabaseSubscriber) {
        subscribers[ObjectIdentifier(subscriber)] = subscriber
    }
    
    func cancel(subscriber: any DatabaseSubscriber) {
        subscriber.onCancel()
        subscribers[ObjectIdentifier(subscriber)] = nil
    }
    
    func receive(event: DatabaseEvent) {
        for subscriber in subscribers.values {
            subscriber.receive(event: event)
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

protocol DatabaseSubscriber: AnyObject {
    func receive(event: DatabaseEvent)
    func onCancel()
}
