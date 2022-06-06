//  ValueOnlySubscriber.swift
//  Propagate
//  Created by Jacob Hawken on 4/5/22.

import Foundation

public extension Subscriber {

    /// Generates a `ValueOnlySubscriber<T>` object, which updates subscribers when the success value
    /// has changed, but ignores failures.
    func valueOnly() -> ValueOnlySubscriber<T> {
        return ValueOnlySubscriber(subscriber: self)
            .onCancelled {
                _ = self
                // To allow the chaining of this operator without having to retain the intervening Subscriber
            }
    }

}

/// Simpler subscriber which only emits new values. Receives cancellation events and consumers can even
/// subscribe to cancellation, but they are not emitted as a bundled state.
///
/// This type of subscsriber is for cases where error handling is unnecessary or where error types get
/// in the way of combining data types. Future versions of this class will likely have a method for
/// generating a new Subscriber from a ValueOnlySubscriber.
public class ValueOnlySubscriber<T> {
    
    public typealias ValueCallback = (T) -> Void
    typealias ValueExecutionPair = (queue: DispatchQueue, action: ValueCallback)
    public typealias CancellationCallback = () -> Void
    typealias CancelExecutionPair = (queue: DispatchQueue, action: CancellationCallback)
    
    
    private let lockQueue = DispatchQueue(label: "ValueOnlySubscriberLockQueue-\(UUID().uuidString)")
    private let callbackQueue = DispatchQueue(label: "ValueOnlySubscriberCallbackQueue-\(UUID().uuidString)")
    private var valueCallbacks = [ValueExecutionPair]()
    private var cancelCallbacks = [CancelExecutionPair]()
    private(set) public var isCancelled = false
    
    fileprivate init() {}
    
    fileprivate init<E: Error>(subscriber: Subscriber<T,E>) {
        subscriber.onNewData { [weak self] value in
            self?.executeValueCallbacks(with: value)
        }
        subscriber.onCancelled { [weak self] in
            self?.cancel()
        }
    }
    
    fileprivate init<OtherT>(other: ValueOnlySubscriber<OtherT>, mapBlock: @escaping (OtherT) -> T) {
        other.onNext { otherVal in
            let value = mapBlock(otherVal)
            self.executeValueCallbacks(with: value)
        }
        other.onCancelled { [weak self] in
            self?.cancel()
        }
    }
    
    /// This mehtod allows you to inflate a ValueOnlySubscriber back to a regular
    /// Subscriber.
    ///
    /// Without doing anything else, however, this will return a Subscriber that
    /// won't ever receive its error state. Error states, however can be injected
    /// conditionally using `splitValueMap(_:)`.
    public func fullSubscriber<E: Error>(errorType: E.Type = E.self) -> Subscriber<T,E> {
        let publisher = Publisher<T,E>()
        
        onNext { publisher.publish($0) }
        
        return publisher.subscriber().onCancelled {
            _ = self // Capturing self to keep subscriber alive for easier chaining.
        }
    }
    
}

public extension ValueOnlySubscriber {
    
    /// Adds a subscription block for new values, to be executed on new data, on the given
    /// dispatch queue. If subscriber is already cancelled, action is neither saved nor executed.
    @discardableResult func onNext(onQueue queue: DispatchQueue, _ action: @escaping ValueCallback) -> Self {
        guard !isCancelled else {
            return self
        }
        lockQueue.async { [weak self] in
            self?.valueCallbacks.append((queue, action))
        }
        return self
    }
    
    /// Adds a subscription block for new values, to be executed on new data, on the subscriber's
    /// internal queue. If subscriber is already cancelled, action is neither saved nor executed.
    @discardableResult func onNext(_ action: @escaping ValueCallback) -> Self {
        onNext(onQueue: callbackQueue, action)
    }
    
    /// Adds a subscription block for cancellation. If subscriber is already cancelled,
    /// action is executed synchronously on the given dispatch queue.
    @discardableResult func onCancelled(
        onQueue queue: DispatchQueue,
        _ action: @escaping CancellationCallback
    ) -> Self {
        guard !isCancelled else {
            queue.sync { action() }
            return self
        }
        lockQueue.async { [weak self] in
            self?.cancelCallbacks.append((queue, action))
        }
        return self
    }
    
    /// Adds a subscription block for cancellation. If subscriber is already cancelled,
    /// action is executed synchronously on the subscriber's internal queue.
    @discardableResult func onCancelled(_ action: @escaping CancellationCallback) -> Self {
        return onCancelled(onQueue: callbackQueue, action)
    }
    
    /// Generates a new ValueOnlySubscriber of a different type, based on the supplied
    /// closure for mapping from one type to the other.
    @discardableResult func map<NewT>(mapping: @escaping (T) -> NewT) -> ValueOnlySubscriber<NewT> {
        return ValueOnlySubscriber<NewT>(other: self, mapBlock: mapping)
    }
    
    /// When T is an optional type, this function generates a new subscriber that only emits
    /// the non-nil states.
    ///
    /// Example:
    /// ```
    /// let optStrings = stringSubscriber.valueOnly() // of type ValueOnlySubscriber<String?>
    /// let strings = optString.compactMap()  // Will be of type ValueOnlySubscriber<String>
    /// ```
    @discardableResult func filterNil<Wrapped>() -> ValueOnlySubscriber<Wrapped> where T == Wrapped? {
        let new = ValueOnlySubscriber<Wrapped>()
        
        onNext { optionalValue in
            if let unwrapped = optionalValue {
                new.executeValueCallbacks(with: unwrapped)
            }
        }
        onCancelled {
            new.cancel()
        }
        
        return new
    }
    
}

private extension ValueOnlySubscriber {
    
    func executeValueCallbacks(with value: T) {
        valueCallbacks.forEach { (queue, action) in
            queue.async { action(value) }
        }
    }
    
    func executeCancelCallbacks() {
        cancelCallbacks.forEach { (queue, action) in
            queue.async { action() }
        }
    }
    
    func cancel() {
        lockQueue.async { [weak self] in
            self?.isCancelled = true
            self?.valueCallbacks.removeAll()
            self?.executeCancelCallbacks()
            self?.cancelCallbacks.removeAll()
        }
    }
    
}
