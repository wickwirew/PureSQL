//
//  Signal.swift
//  Feather
//
//  Created by Wes Wickwire on 2/16/25.
//

final class Signal: Sendable {
    private let stream: AsyncStream<Void>
    private let continuation: AsyncStream<Void>.Continuation

    init() {
        let (stream, continuation) = AsyncStream<Void>.makeStream()
        self.stream = stream
        self.continuation = continuation
    }

    func signal() {
        continuation.finish()
    }
    
    func wait() async {
        for await _ in stream {}
    }
}
