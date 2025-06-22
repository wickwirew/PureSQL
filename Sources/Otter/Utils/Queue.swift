//
//  Queue.swift
//  Otter
//
//  Created by Wes Wickwire on 3/30/25.
//

final class Queue: Sendable {
    typealias Action = @Sendable () async -> Void
    
    private let task: Task<Void, Never>
    private let stream: AsyncStream<Action>
    private let continuation: AsyncStream<Action>.Continuation
    
    init() {
        let (stream, continuation) = AsyncStream<Action>.makeStream()
        self.stream = stream
        self.continuation = continuation
        self.task = Task {
            for await action in stream {
                await action()
            }
        }
    }
    
    deinit {
        task.cancel()
    }
    
    func enqueue(_ action: @escaping Action) {
        continuation.yield(action)
    }
    
    func cancel() {
        task.cancel()
    }
}
