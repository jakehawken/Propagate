//  StreamPublisher.swift
//  Propagate
//  Created by Jake Hawken on 4/5/20.
//  Copyright © 2020 Jake Hawken. All rights reserved.

import Foundation

/// The "fountainhead" object responsible for kicking off events in a
/// data stream. Vends `Subscriber` objects which receive the events
/// emitted by this publisher. A publisher can have zero, one, or many
/// subscribers.
public class Publisher<T, E: Error> {
    
    public typealias State = StreamState<T, E>
    
    fileprivate let lockQueue = DispatchQueue(label: "PublisherLockQueue-\(UUID().uuidString)")
    fileprivate var subscribers = WeakBag<Subscriber<T, E>>()
    private(set) public var isCancelled = false
    
    internal var loggingCombo: (LoggingCombo)?
    
    public init() {
    }
    
    /// Emits a new `StreamState`. If this publisher has previously been
    /// cancelled, this method will be a no-op.
    internal func publishNewState(_ state: State) {
        safePrint("Publishing state \(state). -- \(self)", logType: .pubSub, loggingCombo: loggingCombo)
        lockQueue.async {
            if self.isCancelled {
                return
            }
            self.subscribers.forEach { $0.receive(state) }
        }
    }
    
    deinit {
        safePrint("Releasing \(self) from memory.", logType: .lifeCycle, loggingCombo: loggingCombo)
        // The asynchronous cancelAll() can't be called from deinit
        // because it results in a bad access crash.
        handleCancellation()
    }
    
    /// Returns a subscriber which receives each state published by this publisher.
    ///
    /// At any time the subcsciber can call its own `cancel()` method, which will
    /// remove it from this publisher. Conversely, this publisher can call
    /// `cancelAll()`, which will remove all subscribers and emit the `.cancelled`
    /// state on each of them.
    public func subscriber() -> Subscriber<T, E> {
        /*
         Any changes made to this function's implementation will
         also need to be made to the same method on StatefulPublisher.
         */
        let newSub = Subscriber(canceller: .init { [weak self] in
            self?.removeSubscriber($0)
        })
        lockQueue.async { [weak self] in
            self?.subscribers.insert(newSub)
        }
        safePrint("Generating new subscriber: \(newSub) from \(self)", logType: .lifeCycle, loggingCombo: loggingCombo)
        return newSub
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
    
    /// Publishes a new `.data` state.
    /// - Parameter model: the associated value
    /// for the `.data` state.
    func publish(_ model: T) {
        publishNewState(.data(model))
    }
    
    /// Publishes a new `.error` state.
    /// - Parameter error: the associated value
    /// for the `.error` state.
    func publish(_ error: E) {
        publishNewState(.error(error))
    }
    
    /// Maps a `Result<T,E>` to a `StreamState<T,E>` and
    /// publishes it. A `.success` will map to a `.data`
    /// state, and a `failure` will map to a `.error` state.
    func publishState(forResult result: Result<T,E>) {
        switch result {
        case .success(let value):
            publish(value)
        case .failure(let error):
            publish(error)
        }
    }
    
    /// Removes all subscribers and emits a `.cancelled`
    /// state to each of them.
    ///
    /// This method only triggers actions the first time
    /// it is called. Subsequent calls are a no-op.
    func cancelAll() {
        lockQueue.async {
            self.handleCancellation()
        }
    }
    
}

extension Publisher: PropagateDebuggable {
    
    @discardableResult public func enableLogging(
        logLevel: DebugLogLevel = .all,
        _ additionalMessage: String = "",
        _ logMethod: LoggingMethod = .debugPrint
    ) -> Self {
        self.loggingCombo = (logLevel, additionalMessage, logMethod)
        return self
    }
    
}

// MARK: - private / helpers

private extension Publisher {
    
    func removeSubscriber(_ subscriber: Subscriber<T,E>) {
        safePrint("Removing \(subscriber) from \(self)", logType: .pubSub, loggingCombo: loggingCombo)
        self.subscribers.pruneIf { $0 === subscriber }
        subscriber.receive(.cancelled)
    }
    
    func handleCancellation() {
        if isCancelled {
            return
        }
        isCancelled = true
        let removedSubscribers = subscribers.removeAll()
        safePrint("Removing subscribers: \(removedSubscribers)", logType: .pubSub, loggingCombo: loggingCombo)
        removedSubscribers.forEach {
            safePrint("Sending cancellation signal to \($0)", logType: .pubSub, loggingCombo: loggingCombo)
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

// MARK: - StatefulPublisher -

/// A publisher which constantly maintains the last state received.
/// Subscribers generated by this publisher emit synchronously when
/// subscribed to, if a previous state exists, and then behave as
/// normal afterward.
public class StatefulPublisher<T,E: Error>: Publisher<T, E> {

    private var _lastState: State?
    /// The last state received, if any.
    public private(set) var lastState: State? {
        get {
            return _lastState
        }
        set {
            if let value = newValue { // Value is only saved if non-nil
                _lastState = value
            }
        }
    }
    
    private var _lastValue: T?
    public private(set) var lastValue: T? {
        get {
            return _lastValue
        }
        set {
            if let value = newValue {
                _lastValue = value
            }
        }
    }
    
    public override init() {
        super.init()
    }
    
    override func publishNewState(_ state: State) {
        lastState = state
        lastValue = state.value //Computed property ignores nil, so this is ok.
        super.publishNewState(state)
    }
    
    public override func subscriber() -> Subscriber<T, E> {
        /*
         Any changes made to this function's implementation will
         also need to be made to the same method on Publisher.
         */
        let newSub = OnSubscribeCallbackSubscriber(canceller: .init { [weak self] in
            self?.removeSubscriber($0)
        })
        newSub.lastStateCallback = { [weak self] in self?.lastState }
        
        lockQueue.async { [weak self] in
            self?.subscribers.insert(newSub)
        }
        safePrint(
            "Generating new subscriber. -- \(self) --> \(newSub)",
            logType: .lifeCycle,
            loggingCombo: loggingCombo
        )
        return newSub
    }
    
}

public extension Publisher where T == Void {
    
    func kick() {
        publish(())
    }
    
}
