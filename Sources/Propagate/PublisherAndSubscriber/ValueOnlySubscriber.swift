//  ValueOnlySubscriber.swift
//  Propagate
//  Created by Jacob Hawken on 4/5/22.

import Foundation

public extension Subscriber {

    /// Generates a `ValueOnlySubscriber<T>` object, which updates subscribers when the success value
    /// has changed, but ignores failures.
    func valueOnly() -> ValueOnlySubscriber<T> {
        return ValueOnlySubscriber(subscriber: self)
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
    
}

public extension ValueOnlySubscriber {
    
    /// Adds a subscription block for new values, to be executed on new data, on the given
    /// dispatch queue. If subscriber is already cancelled, action is neither saved nor executed.
    func onNext(onQueue queue: DispatchQueue, _ action: @escaping ValueCallback) {
        guard !isCancelled else {
            return
        }
        lockQueue.async { [weak self] in
            self?.valueCallbacks.append((queue, action))
        }
    }
    
    /// Adds a subscription block for new values, to be executed on new data, on the subscriber's
    /// internal queue. If subscriber is already cancelled, action is neither saved nor executed.
    func onNext(_ action: @escaping ValueCallback) {
        onNext(onQueue: callbackQueue, action)
    }
    
    /// Adds a subscription block for cancellation. If subscriber is already cancelled,
    /// action is executed synchronously on the given dispatch queue.
    func onCancelled(onQueue queue: DispatchQueue, _ action: @escaping CancellationCallback) {
        guard !isCancelled else {
            queue.sync { action() }
            return
        }
        lockQueue.async { [weak self] in
            self?.cancelCallbacks.append((queue, action))
        }
    }
    
    /// Adds a subscription block for cancellation. If subscriber is already cancelled,
    /// action is executed synchronously on the subscriber's internal queue.
    func onCancelled(_ action: @escaping CancellationCallback) {
        onCancelled(onQueue: callbackQueue, action)
    }
    
    /// Generates a new ValueOnlySubscriber of a different type, based on the supplied
    /// closure for mapping from one type to the other.
    func map<NewT>(mapping: @escaping (T) -> NewT) -> ValueOnlySubscriber<NewT> {
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
    func compactMap<Wrapped>() -> ValueOnlySubscriber<Wrapped> where T == Wrapped? {
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
