//
//  Lock.swift
//  PureSQL
//
//  Created by Wes Wickwire on 2/16/25.
//

/// A lock that suspends instead of blocks.
final actor Lock {
    typealias Continuation = CheckedContinuation<Void, Never>
    
    private var state: State = .unlocked
    
    enum State {
        case unlocked
        case locked([Continuation])
    }
    
    init() {}

    func lock() async {
        switch state {
        case .unlocked:
            state = .locked([])
        case var .locked(continuations):
            await withCheckedContinuation { continuation in
                continuations.append(continuation)
                state = .locked(continuations)
            }
        }
    }
    
    func unlock() {
        switch state {
        case .unlocked:
            return
        case var .locked(continuations):
            guard !continuations.isEmpty else {
                state = .unlocked
                return
            }
            
            let first = continuations.removeFirst()
            state = .locked(continuations)
            first.resume()
        }
    }
}
