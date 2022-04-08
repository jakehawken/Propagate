//  Subscriber.swift
//  JSync
//  Created by Jake Hawken on 4/5/20.
//  Copyright © 2020 Jake Hawken. All rights reserved.

import Foundation

public class Subscriber<T, E: Error> {
    
    public typealias State = StreamState<T,E>
    public typealias Callback = (State) -> Void
    private typealias ExecutionPair = (queue: DispatchQueue, action: Callback)
    
    private let canceller: Canceller<T,E>
    private let lockQueue = DispatchQueue(label: "SubscriberLockQueue-\(UUID().uuidString)")
    private lazy var callbackQueue = DispatchQueue(label: "SubscriberCallbackQueue-\(UUID().uuidString)")
    private lazy var callbacks = SinglyLinkedList<ExecutionPair>(firstValue: (callbackQueue, { _ in }))
    
    internal init(canceller: Canceller<T,E>) {
        self.canceller = canceller
        self.callbackQueue = callbackQueue
    }
    
    deinit {
        safePrint("Releasing \(self) from memory.", logType: .lifeCycle)
        cancel()
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
    
    func cancel() {
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
    }
    
}

// MARK: - Subscription

public extension Subscriber {
    
    // MARK: general
    
    @discardableResult func subscribe(onQueue queue: DispatchQueue, performing callback: @escaping (State) -> Void) -> Self {
        lockQueue.async { [weak self] in
            self?.callbacks.append((queue, callback))
        }
        return self
    }
    
    @discardableResult func subscribe(performing callback: @escaping (State) -> Void) -> Self {
        subscribe(onQueue: callbackQueue, performing: callback)
    }
    
    @discardableResult func subscribeOnMain(performing callback: @escaping (State) -> Void) -> Self {
        subscribe(onQueue: .main, performing: callback)
    }
    
    // MARK: new data only
    
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
    
    @discardableResult func onNewData(perform dataAction: @escaping (T) -> Void) -> Self {
        onNewData(onQueue: callbackQueue, perform: dataAction)
    }
    
    // MARK: error only
    
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
    
    @discardableResult func onError(perform callback: @escaping (E) -> Void) -> Self {
        onError(onQueue: callbackQueue, perform: callback)
    }
    
    // MARK: cancel only
    
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
    
    @discardableResult func onCancelled(perform callback: @escaping () -> Void) -> Self {
        onCancelled(onQueue: callbackQueue, perform: callback)
    }
    
}
