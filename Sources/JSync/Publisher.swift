//  StreamPublisher.swift
//  Propagate
//  Created by Jake Hawken on 4/5/20.
//  Copyright © 2020 Jake Hawken. All rights reserved.

import Foundation

public class Publisher<T, E: Error> {
    
    public typealias State = StreamState<T, E>
    
    private let lockQueue = DispatchQueue(label: "PublisherLockQueue-\(UUID().uuidString)")
    private var subscribers = WeakBag<Subscriber<T, E>>()
    private(set) public var isCancelled = false
    
    public init() {
        safePrint("Created new publisher: \(self)", logType: .lifeCycle)
    }
    
    internal func publishNewState(_ state: State) {
        safePrint("Publishing state \(state) from \(self)", logType: .pubSub)
        lockQueue.async {
            guard !self.isCancelled else {
                return
            }
            self.subscribers.forEach { $0.receive(state) }
        }
    }
    
    deinit {
        safePrint("Releasing \(self) from memory.", logType: .lifeCycle)
        // The asynchronous cancelAll() can't be called from deinit
        // because it results in a bad access crash.
        handleCancellation()
    }
    
}

// MARK: debugging

extension Publisher: CustomStringConvertible {
    
    public var description: String {
        return "Publisher<\(T.self),\(E.self)>(\(memoryAddressStringFor(self)))"
    }
    
}

// MARK: - Main interface

public extension Publisher {
    
    func subscriber() -> Subscriber<T, E> {
        let canceller = Canceller<T,E> { [weak self] in
            self?.removeSubscriber($0)
        }
        let newSub = Subscriber(canceller: canceller)
        lockQueue.async { [weak self] in
            self?.subscribers.insert(newSub)
        }
        safePrint("Generating new subscriber: \(newSub) from \(self)", logType: .lifeCycle)
        return newSub
    }
    
    func publish(_ model: T) {
        publishNewState(.data(model))
    }
    
    func publish(_ error: E) {
        publishNewState(.error(error))
    }
    
    func cancelAll() {
        lockQueue.async {
            self.handleCancellation()
        }
    }
    
}

// MARK: - private / helpers

private extension Publisher {
    
    func removeSubscriber(_ subscriber: Subscriber<T,E>) {
        safePrint("Removing \(subscriber) from \(self)", logType: .pubSub)
        self.subscribers.pruneIf { $0 === subscriber }
    }
    
    func handleCancellation() {
        if isCancelled {
            return
        }
        isCancelled = true
        let removedSubscribers = subscribers.removeAll()
        safePrint("Removing subscribers: \(removedSubscribers)", logType: .pubSub)
        removedSubscribers.forEach {
            safePrint("Sending cancellation signal to \($0)", logType: .pubSub)
            $0.receive(.cancelled)
        }
    }
    
}

// MARK: - Supporting Types

class Canceller<T, E: Error> {
    
    private var cancelAction: ((Subscriber<T,E>) -> Void)?
    
    init(cancelAction: @escaping (Subscriber<T,E>) -> Void) {
        self.cancelAction = cancelAction
    }
    
    internal func cancel(for subscriber: Subscriber<T,E>) {
        guard let action = cancelAction else {
            return
        }
        cancelAction = nil
        action(subscriber)
    }
    
}
