//
//  SQLiteCode.swift
//  PureSQL
//
//  Created by Wes Wickwire on 11/9/24.
//

import SQLite3

public enum SQLiteCode: Int32, Error {
    case sqliteOk = 0
    case sqliteAbort = 4
    case sqliteAuth = 23
    case sqliteBusy = 5
    case sqliteCantopen = 14
    case sqliteConstraint = 19
    case sqliteCorrupt = 11
    case sqliteDone = 101
    case sqliteEmpty = 16
    case sqliteError = 1
    case sqliteFormat = 24
    case sqliteFull = 13
    case sqliteInternal = 2
    case sqliteInterrupt = 9
    case sqliteIoerr = 10
    case sqliteLocked = 6
    case sqliteMismatch = 20
    case sqliteMisuse = 21
    case sqliteNolfs = 22
    case sqliteNomem = 7
    case sqliteNotadb = 26
    case sqliteNotfound = 12
    case sqliteNotice = 27
    case sqlitePerm = 3
    case sqliteProtocol = 15
    case sqliteRange = 25
    case sqliteReadonly = 8
    case sqliteRow = 100
    case sqliteSchema = 17
    case sqliteToobig = 18
    case sqliteWarning = 28
    case sqliteAbortRollback = 516
    case sqliteAuthUser = 279
    case sqliteBusyRecovery = 261
    case sqliteBusySnapshot = 517
    case sqliteBusyTimeout = 773
    case sqliteCantopenConvpath = 1038
    case sqliteCantopenDirtywal = 1294
    case sqliteCantopenFullpath = 782
    case sqliteCantopenIsdir = 526
    case sqliteCantopenNotempdir = 270
    case sqliteCantopenSymlink = 1550
    case sqliteConstraintCheck = 275
    case sqliteConstraintCommithook = 531
    case sqliteConstraintDatatype = 3091
    case sqliteConstraintForeignkey = 787
    case sqliteConstraintFunction = 1043
    case sqliteConstraintNotnull = 1299
    case sqliteConstraintPinned = 2835
    case sqliteConstraintPrimarykey = 1555
    case sqliteConstraintRowid = 2579
    case sqliteConstraintTrigger = 1811
    case sqliteConstraintUnique = 2067
    case sqliteConstraintVtab = 2323
    case sqliteCorruptIndex = 779
    case sqliteCorruptSequence = 523
    case sqliteCorruptVtab = 267
    case sqliteErrorMissingCollseq = 257
    case sqliteErrorRetry = 513
    case sqliteErrorSnapshot = 769
    case sqliteIoerrAccess = 3338
    case sqliteIoerrAuth = 7178
    case sqliteIoerrBeginAtomic = 7434
    case sqliteIoerrBlocked = 2826
    case sqliteIoerrCheckreservedlock = 3594
    case sqliteIoerrClose = 4106
    case sqliteIoerrCommitAtomic = 7690
    case sqliteIoerrConvpath = 6666
    case sqliteIoerrCorruptfs = 8458
    case sqliteIoerrData = 8202
    case sqliteIoerrDelete = 2570
    case sqliteIoerrDeleteNoent = 5898
    case sqliteIoerrDirClose = 4362
    case sqliteIoerrDirFsync = 1290
    case sqliteIoerrFstat = 1802
    case sqliteIoerrFsync = 1034
    case sqliteIoerrGettemppath = 6410
    case sqliteIoerrLock = 3850
    case sqliteIoerrMmap = 6154
    case sqliteIoerrNomem = 3082
    case sqliteIoerrRdlock = 2314
    case sqliteIoerrRead = 266
    case sqliteIoerrRollbackAtomic = 7946
    case sqliteIoerrSeek = 5642
    case sqliteIoerrShmlock = 5130
    case sqliteIoerrShmmap = 5386
    case sqliteIoerrShmopen = 4618
    case sqliteIoerrShmsize = 4874
    case sqliteIoerrShortRead = 522
    case sqliteIoerrTruncate = 1546
    case sqliteIoerrUnlock = 2058
    case sqliteIoerrVnode = 6922
    case sqliteIoerrWrite = 778
    case sqliteLockedSharedcache = 262
    case sqliteLockedVtab = 518
    case sqliteNoticeRecoverRollback = 539
    case sqliteNoticeRecoverWal = 283
    case sqliteOkLoadPermanently = 256
    case sqliteReadonlyCantinit = 1288
    case sqliteReadonlyCantlock = 520
    case sqliteReadonlyDbmoved = 1032
    case sqliteReadonlyDirectory = 1544
    case sqliteReadonlyRecovery = 264
    case sqliteReadonlyRollback = 776
    case sqliteWarningAutoindex = 284

    var isError: Bool {
        return self != .sqliteOk
    }

    init(_ rc: Int32) {
        self = .init(rawValue: rc) ?? .sqliteOk
    }
}

func throwing(_ rc: Int32, connection: OpaquePointer? = nil) throws(SQLError) {
    guard rc != SQLITE_OK, let code = SQLiteCode(rawValue: rc) else { return }
    // Memory for the error is managed by SQLite so we don't need to free it.
    throw .sqlite(code, String(cString: sqlite3_errmsg(connection)))
}
