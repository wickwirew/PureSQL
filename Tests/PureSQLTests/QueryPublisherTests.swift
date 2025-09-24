//
//  QueryPublisherTests.swift
//  PureSQL
//
//  Created by Wes Wickwire on 2/18/25.
//

#if canImport(Combine)
import Combine
import Foundation
@testable import PureSQL
import Testing

@Suite
struct QueryPublisherTests {
    @Test func demandOfMaxOnlyReturnsASingleValue() async throws {
        let db = try TestDB.inMemory()

        try await db.insertFoo.execute(1)
        
        let subscriber = TestSubscriber<[TestDB.Foo]>()
        db.selectFoos.publisher().subscribe(subscriber)
        subscriber.request(.max(.max))
        
        let values1 = await first(from: subscriber.received)
        #expect(values1 == [TestDB.Foo(bar: 1)])
        
        try await db.insertFoo.execute(2)
        let values2 = await first(from: subscriber.received)
        #expect(values2 == [TestDB.Foo(bar: 1), TestDB.Foo(bar: 2)])
        
        try await db.insertFoo.execute(3)
        let values3 = await first(from: subscriber.received)
        #expect(values3 == [TestDB.Foo(bar: 1), TestDB.Foo(bar: 2), TestDB.Foo(bar: 3)])
        
        subscriber.subscription?.cancel()
    }
    
    @Test func demandOfOneOnlyReturnsASingleValue() async throws {
        let db = try TestDB.inMemory()

        try await db.insertFoo.execute(1)
        
        let subscriber = TestSubscriber<[TestDB.Foo]>()
        db.selectFoos.publisher().subscribe(subscriber)
        subscriber.request(.max(1))
        
        let value = await first(from: subscriber.received)
        #expect(value == [TestDB.Foo(bar: 1)])
        
        try await db.insertFoo.execute(2)
        let nextValue = await first(from: subscriber.received, timeout: .milliseconds(100))
        #expect(nextValue == nil)
        
        subscriber.subscription?.cancel()
    }
    
    @Test func demandOfNoneOnlyReturnsASingleValue() async throws {
        let db = try TestDB.inMemory()

        try await db.insertFoo.execute(1)
        
        let subscriber = TestSubscriber<[TestDB.Foo]>()
        db.selectFoos.publisher().subscribe(subscriber)
        subscriber.request(.none)

        let value = await first(from: subscriber.received, timeout: .milliseconds(100))
        #expect(value == nil)
        
        subscriber.subscription?.cancel()
    }
    
    final class TestSubscriber<Input: Sendable>: Subscriber {
        typealias Failure = Error
        var subscription: Subscription?
        var (received, receivedCont) = AsyncStream<Input>.makeStream()
        
        func request(_ demand: Subscribers.Demand) {
            guard let subscription else {
                Issue.record("Subscription not started")
                return
            }
            
            subscription.request(demand)
        }
        
        func receive(subscription: any Subscription) {
            self.subscription = subscription
        }
        
        func receive(_ input: Input) -> Subscribers.Demand {
            receivedCont.yield(input)
            return .none
        }
        
        func receive(completion: Subscribers.Completion<any Failure>) {}
    }
    
    private func first<T>(from stream: AsyncStream<T>) async -> T? {
        for await value in stream {
            return value
        }
        
        return nil
    }
    
    private func first<T: Sendable>(from stream: AsyncStream<T>, timeout: Duration) async -> T? {
        let lock = NSLock()
        nonisolated(unsafe) var didReturn = false
        
        let shouldReturn: @Sendable () -> Bool = {
            lock.withLock {
                guard !didReturn else { return false }
                didReturn = true
                return true
            }
        }
        
        return await withCheckedContinuation { cont in
            let task1 = Task {
                for await value in stream {
                    guard shouldReturn() else { return }
                    cont.resume(returning: value)
                    return
                }
            }
            
            Task {
                try await Task.sleep(for: timeout)
                guard shouldReturn() else { return }
                cont.resume(returning: nil)
                task1.cancel()
            }
        }
    }
}
#endif
