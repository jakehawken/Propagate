//  UpdateOnlySubscriber.swift
//  Propagate
//  Created by Jacob Hawken on 4/5/22.

import Foundation

public extension Subscriber {
    
    /// Generates an UpdateOnlySubscriber object, which updates subscribers when new new data
    /// events occur, but does not pass along those values.
    ///
    /// - Parameter includeErrors: A boolean which indicates whether the UpdateOnlySubscriber
    /// should also call subscription closures on error events. If false, subscription closures
    /// will only trigger on new data events.
    func didUpdate(includeErrors: Bool = false) -> UpdateOnlySubscriber {
        return UpdateOnlySubscriber(subscriber: self, includeErrors: includeErrors)
        /// Note: Does not need a `.onCancelled { _ = self }` operation appended
        /// like other operators do because it already retains a reference to the
        /// subscriber, by nature of its implementation.
    }
    
}

/// Simplest possible subscriber which emits when new values are received, but does not emit
/// those values themselves. Receives cancellation events and consumers can even subscribe to
/// cancellation, but new data and cancellation are not emitted as a bundled state. If
/// UpdateOnlySubscriber is constructed with the `includeErrors` flag, the subscription callbacks
/// will be called on both new data and error states.
///
/// This type of subscriber is for cases where only the fact that an update has occurred is needed,
/// or where complete type erasure of a Subscriber is needed.
public class UpdateOnlySubscriber {
    
    private var simpleSubscribeClosure: (@escaping () -> Void) -> Void
    private var subscribeOnQueueClosure: (DispatchQueue, @escaping () -> Void) -> Void
    private var simpleCancelClosure: (@escaping () -> Void) -> Void
    private var cancelOnQueueClosure: (DispatchQueue, @escaping () -> Void) -> Void
    
    fileprivate init<T, E: Error>(subscriber: Subscriber<T, E>, includeErrors: Bool) {
        simpleSubscribeClosure = { callback in
            subscriber.onNewData { _ in
                callback()
            }
            if includeErrors {
                subscriber.onError { _ in
                    callback()
                }
            }
        }
        subscribeOnQueueClosure = { queue, callback in
            subscriber.onNewData(onQueue: queue) { _ in
                callback()
            }
            if includeErrors {
                subscriber.onError(onQueue: queue) { _ in
                    callback()
                }
            }
        }
        simpleCancelClosure = { callback in
            subscriber.onCancelled(perform: callback)
        }
        cancelOnQueueClosure = { queue, callback in
            subscriber.onCancelled(onQueue: queue, perform: callback)
        }
    }
    
    /// This mehtod allows you to inflate a UpdateOnlySubscriber back to a regular
    /// Subscriber.
    ///
    /// Without doing anything else, however, this will return a Subscriber that
    /// won't ever receive its error state. Error states, however can be injected
    /// conditionally using `splitValueMap(_:)`.
    public func fullSubscriber<E: Error>(errorType: E.Type = E.self) -> Subscriber<Void,E> {
        let publisher = Publisher<Void,E>()
        
        subscribe { publisher.publish(()) }
        
        return publisher.subscriber().onCancelled {
            _ = self // Capturing self to keep subscriber alive for easier chaining.
        }
    }
    
}

public extension UpdateOnlySubscriber {
    
    /// Adds a subscription block for when the underlying Subscriber receives new data, and is
    /// executed on the given dispatch queue.
    func subscribe(onQueue queue: DispatchQueue, _ action: @escaping () -> Void) -> Self {
        subscribeOnQueueClosure(queue, action)
        return self
    }
    
    /// Adds a subscription block for when the underlying Subscriber receives new data, and is
    /// executed on the Subscriber's internal dispatch queue.
    @discardableResult func subscribe(_ action: @escaping () -> Void) -> Self {
        simpleSubscribeClosure(action)
        return self
    }
    
    /// Adds a subscription block for when the underlying Subscriber is cancelled, and is
    /// executed on the given dispatch queue.
    func onCancelled(onQueue queue: DispatchQueue, _ action: @escaping () -> Void) -> Self {
        cancelOnQueueClosure(queue, action)
        return self
    }
    
    /// Adds a subscription block for when the underlying Subscriber is cancelled, and is
    /// executed on the Subscriber's internal dispatch queue.
    @discardableResult func onCancelled(_ action: @escaping () -> Void) -> Self {
        simpleCancelClosure(action)
        return self
    }
    
}
