//
//  DatabaseObserver.swift
//  PureSQL
//
//  Created by Wes Wickwire on 2/26/25.
//

import Foundation
import SQLite3

/// A change that happened in the database.
/// Represents many events. Changes are published
/// after commit which may contain many events
/// that happened within the transaction.
public struct DatabaseChange {
    /// A set of tables that we affected by the commit
    public let affectedTables: Set<String>
    /// The raw list of events from SQLite
    public let events: [DatabaseEvent]
}

/// The raw fields SQLite gives us doing an `update_hook`
public struct DatabaseEvent: Sendable {
    /// What kind of operation happened
    public let operation: Operation
    /// The database affected if any
    public let databaseName: String?
    /// The table affected if any
    public let tableName: String?
    /// The row id of the affected row.
    public let rowId: Int64
    
    public enum Operation: Int32, Sendable {
        case insert = 18 // SQLITE_INSERT
        case delete = 9 // SQLITE_DELETE
        case update = 23 // SQLITE_UPDATE
    }
}

/// Manages all of the subscriptions to a database.
/// Will listen to SQLites hooks as well as recieve
/// `didCommit` calls from the owning database `Connection`.
class DatabaseObserver: @unchecked Sendable {
    /// Lock to protect the `subscribers`.
    /// Would have been nice to make this an actor but it would
    /// have made things `async` that shouldn't be like
    /// cancellation and others.
    private let lock = NSLock()
    /// A map of all subscribers. The key is their pointer
    private var subscribers: [ObjectIdentifier: any DatabaseSubscriber] = [:]
    /// We get the events from the database before the commit happens.
    /// So if a caller requeries the database they will get old
    /// data since the write would be in an uncommited transaction.
    /// So we keep a list of all events that happened and then
    /// on commit we can dispatch them all.
    private var pendingEvents: [DatabaseEvent] = []
    
    /// Subscribes the `subscriber` to any database events.
    /// Events are flushed upon commit and not as they come in.
    func subscribe(subscriber: any DatabaseSubscriber) {
        lock.withLock {
            let id = ObjectIdentifier(subscriber)
            guard subscribers[id] == nil else { return }
            subscribers[id] = subscriber
        }
    }
    
    /// Cancels the subscribers subscription.
    func cancel(subscriber: any DatabaseSubscriber) {
        lock.withLock {
            subscribers[ObjectIdentifier(subscriber)] = nil
        }
    }
    
    /// Must be called by the owning database.
    /// We do not use `sqlite3_commit_hook` since it is actually
    /// called during the commit. Not after it.
    func didCommit() {
        lock.withLock {
            let events = pendingEvents
            pendingEvents.removeAll()
            
            // Merge all events into a single change
            let change = DatabaseChange(
                affectedTables: Set(events.compactMap(\.tableName)),
                events: events
            )
            
            for subscriber in subscribers.values {
                subscriber.receive(change: change)
            }
        }
    }
    
    /// SQLite hooks are a per connection thing. Updates from
    /// one connection do no publish on another so the owning
    /// database must install the hooks for event connection
    /// it initializes.
    func installHooks(into connection: SQLiteConnection) {
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
    
    private func receiveSqliteUpdateHook(
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
        
        lock.withLock {
            pendingEvents.append(event)
        }
    }
}

/// A subscriber that listens to database changes
public protocol DatabaseSubscriber: AnyObject {
    /// After a commit, this is called with the `change`
    /// which contains the events that happened during the
    /// transaction and any additional metadata
    ///
    /// - Parameter change: The metadata about the change.
    func receive(change: DatabaseChange)
}
