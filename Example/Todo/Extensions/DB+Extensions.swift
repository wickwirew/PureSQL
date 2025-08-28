//
//  DB+Extensions.swift
//  Todo
//
//  Created by Wes Wickwire on 8/27/25.
//

import Foundation

extension DB {
    init() throws {
        if ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1" {
            self = try DB.inMemory()
        } else {
            let appSupportURL = try FileManager.default.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )
            let directoryURL = appSupportURL.appendingPathComponent("Database", isDirectory: true)
            let dbURL = directoryURL.appendingPathComponent("db.sqlite")
            try FileManager.default.createDirectory(
                at: directoryURL,
                withIntermediateDirectories: true
            )
            self = try DB(url: dbURL)
        }
    }
}
