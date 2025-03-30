//
//  Observation.swift
//  Feather
//
//  Created by Wes Wickwire on 2/26/25.
//

import SQLite3
import Foundation

public struct DatabaseEvent: Sendable {
    public let operation: Operation
    public let databaseName: String?
    public let tableName: String?
    public let rowId: Int64
    
    public enum Operation: Int32, Sendable {
        case insert = 18 // SQLITE_INSERT
        case delete = 9 // SQLITE_DELETE
        case update = 23 // SQLITE_UPDATE
    }
}

class DatabaseObserver: @unchecked Sendable {
    private let lock = NSLock()
    private var subscribers: [ObjectIdentifier: any DatabaseSubscriber] = [:]

    private var pendingEvents: [DatabaseEvent] = []
    
    func subscribe(subscriber: any DatabaseSubscriber) {
        lock.lock()
        defer { lock.unlock() }
        
        let id = ObjectIdentifier(subscriber)
        
        guard subscribers[id] == nil else {
            return
        }
        
        subscribers[id] = subscriber
    }
    
    func cancel(subscriber: any DatabaseSubscriber) {
        lock.lock()
        defer { lock.unlock() }
        
        subscribers[ObjectIdentifier(subscriber)] = nil
    }
    
    func receive(event: DatabaseEvent) {
        lock.lock()
        defer { lock.unlock() }
        
        pendingEvents.append(event)
    }
    
    func didCommit() {
        lock.lock()
        defer { lock.unlock() }
        
        let events = pendingEvents
        pendingEvents.removeAll()
        
        for subscriber in subscribers.values {
            for event in events {
                subscriber.receive(event: event)
            }
        }
    }
    
    func installHooks(into connection: Connection) {
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
    
    func receiveSqliteUpdateHook(
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
        
        receive(event: event)
    }
}

public protocol DatabaseSubscriber: AnyObject {
    func receive(event: DatabaseEvent)
}
