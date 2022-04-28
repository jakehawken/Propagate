//  Subscriber.swift
//  Propagate
//  Created by Jake Hawken on 4/5/20.
//  Copyright © 2020 Jake Hawken. All rights reserved.

import Foundation

/// The receiver object for states emitted by a Publisher. Manages subscriptions
/// to stream states, and manages the dispatch queues callbacks will be called from.
public class Subscriber<T, E: Error> {
    
    public typealias State = StreamState<T,E>
    public typealias Callback = (State) -> Void
    private typealias ExecutionPair = (queue: DispatchQueue, action: Callback)
    
    private let canceller: Canceller<T,E>
    private let lockQueue = DispatchQueue(label: "SubscriberLockQueue-\(UUID().uuidString)")
    private lazy var callbackQueue = DispatchQueue(label: "SubscriberCallbackQueue-\(UUID().uuidString)")
    private lazy var callbacks = SinglyLinkedList<ExecutionPair>(firstValue: (callbackQueue, { _ in }))
    
    private(set) public var isCancelled = false
    
    internal init(canceller: Canceller<T,E>) {
        self.canceller = canceller
        self.callbackQueue = callbackQueue
    }
    
    deinit {
        safePrint("Releasing \(self) from memory.", logType: .lifeCycle)
        cancel()
    }
    
    /// Adds a callback to the subscriber which is called for each StreamState event.
    /// Callbacks are called on the supplied dispatch queue.
    /// - Parameter onQueue: the dispatch queue on which the callback is to be performed.
    /// - Parameter performing: the callback to be executed on new states
    /// - returns: The subscriber itself, as a `@discardableResult` to allow for easy
    /// chaining of operators.
    @discardableResult public func subscribe(onQueue queue: DispatchQueue, performing callback: @escaping (State) -> Void) -> Self {
        lockQueue.async { [weak self] in
            self?.callbacks.append((queue, callback))
        }
        return self
    }
    
}

// MARK: - Convenience

internal extension Subscriber {
    
    func receive(_ state: StreamState<T,E>) {
        lockQueue.async { [weak self] in
            self?.executeCallbacks(forState: state)
        }
    }
    
    func receive(_ data: T) {
        receive(.data(data))
    }
    
    func receive(_ error: E) {
        receive(.error(error))
    }
    
    /// Calling this method removes this subscriber from
    /// its publisher. This will result in this subscriber
    /// immediately receiving a `.cancelled` signal.
    func cancel() {
        isCancelled = true
        canceller.cancel(for: self)
    }
    
}

// MARK: - basic helpers

private extension Subscriber {
    
    func executeCallbacks(forState state: State) {
        safePrint("\(self) received \(state)", logType: .pubSub)
        callbacks.forEach { (queue, action) in
            queue.async { action(state) }
        }
        if case .cancelled = state {
            isCancelled = true
            callbacks.trimToRoot()
        }
    }
    
}

// MARK: - Subscription

public extension Subscriber {
    
    // MARK: general
    
    /// Adds a callback to the subscriber which is called for each StreamState event.
    /// Callbacks are called on the subscriber's default internal dispatch queue.
    /// - Parameter performing: the callback to be executed on new states
    /// - returns: The subscriber itself, as a `@discardableResult` to allow for easy
    /// chaining of operators.
    @discardableResult func subscribe(performing callback: @escaping (State) -> Void) -> Self {
        subscribe(onQueue: callbackQueue, performing: callback)
    }
    
    /// Adds a callback to the subscriber which is called for each StreamState event.
    /// Callbacks are called on `DispatchQueue.main`.
    /// - Parameter performing: the callback to be executed on new states
    /// - returns: The subscriber itself, as a `@discardableResult` to allow for easy
    /// chaining of operators.
    @discardableResult func subscribeOnMain(performing callback: @escaping (State) -> Void) -> Self {
        subscribe(onQueue: .main, performing: callback)
    }
    
    // MARK: - new data only
    
    /// Adds a callback to the subscriber which is called for all `.data` states.
    /// Callbacks are called on the supplied dispatch queue.
    /// - Parameter onQueue: the dispatch queue on which the callback is to be performed.
    /// - Parameter perform: the callback to be executed on `.data` states
    /// - returns: The subscriber itself, as a `@discardableResult` to allow for easy
    /// chaining of operators.
    @discardableResult func onNewData(onQueue queue: DispatchQueue, perform callback: @escaping (T) -> Void) -> Self {
        subscribe(onQueue: queue) { (state: State) in
            switch state {
            case let .data(newData):
                callback(newData)
            default:
                break
            }
        }
    }
    
    /// Adds a callback to the subscriber which is called for all `.data` states.
    /// Callbacks are called on the subscriber's default internal dispatch queue.
    /// - Parameter perform: the callback to be executed on `.data` states
    /// - returns: The subscriber itself, as a `@discardableResult` to allow for easy
    /// chaining of operators.
    @discardableResult func onNewData(perform dataAction: @escaping (T) -> Void) -> Self {
        onNewData(onQueue: callbackQueue, perform: dataAction)
    }
    
    // MARK: - error only
    
    /// Adds a callback to the subscriber which is called for all `.error` states.
    /// Callbacks are called on the supplied dispatch queue.
    /// - Parameter onQueue: the dispatch queue on which the callback is to be performed.
    /// - Parameter perform: the callback to be executed on `.error` states
    /// - returns: The subscriber itself, as a `@discardableResult` to allow for easy
    /// chaining of operators.
    @discardableResult func onError(onQueue queue: DispatchQueue, perform callback: @escaping (E) -> Void) -> Self {
        subscribe(onQueue: queue) { (state: State) in
            switch state {
            case let .error(error):
                callback(error)
            default:
                break
            }
        }
    }
    
    /// Adds a callback to the subscriber which is called for all `.error` states.
    /// Callbacks are called on the subscriber's default internal dispatch queue.
    /// - Parameter perform: the callback to be executed on `.error` states
    /// - returns: The subscriber itself, as a `@discardableResult` to allow for easy
    /// chaining of operators.
    @discardableResult func onError(perform callback: @escaping (E) -> Void) -> Self {
        onError(onQueue: callbackQueue, perform: callback)
    }
    
    // MARK: cancel only
    
    /// Adds a callback to the subscriber which is called for all `.cancelled` states.
    /// Callbacks are called on the supplied dispatch queue.
    /// - Parameter onQueue: the dispatch queue on which the callback is to be performed.
    /// - Parameter perform: the callback to be executed on `.cancelled` states
    /// - returns: The subscriber itself, as a `@discardableResult` to allow for easy
    /// chaining of operators.
    @discardableResult func onCancelled(onQueue queue: DispatchQueue, perform callback: @escaping () -> Void) -> Self {
        subscribe(onQueue: queue) { (state: State) in
            switch state {
            case .cancelled:
                callback()
            default:
                break
            }
        }
    }
    
    /// Adds a callback to the subscriber which is called for all `.cancelled` states.
    /// Callbacks are called on the subscriber's default internal dispatch queue.
    /// - Parameter perform: the callback to be executed on `.cancelled` states
    /// - returns: The subscriber itself, as a `@discardableResult` to allow for easy
    /// chaining of operators.
    @discardableResult func onCancelled(perform callback: @escaping () -> Void) -> Self {
        onCancelled(onQueue: callbackQueue, perform: callback)
    }
    
}

public extension Subscriber {
    
    /// Binds this subscriber to a publisher of the same type. Each StreamState received
    /// by this subscriber will be published by the publisher it has been bound to.
    @discardableResult func bindTo(_ publisher: Publisher<T,E>) -> Self {
        subscribe {
            publisher.publishNewState($0)
        }
        return self
    }
    
}

// MARK: - OnSubscribe callback subscriber

/// Exists solely to give the subscriber the ability to
/// emit the last value (if it exists) synchronously.
/// Internal to the framkework.
class OnSubscribeCallbackSubscriber<T,E: Error>: Subscriber<T,E> {
    
    var lastStateCallback: () -> State? = { nil }
    
    override func subscribe(onQueue queue: DispatchQueue, performing callback: @escaping (Subscriber<T, E>.State) -> Void) -> Self {
        if let lastState = lastStateCallback() {
            callback(lastState)
            if case .cancelled = lastState {
                return self
            }
        }
        return super.subscribe(onQueue: queue, performing: callback)
    }
    
}
