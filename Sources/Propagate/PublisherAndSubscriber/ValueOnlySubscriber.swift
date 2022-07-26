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
    private var loggingCombo: LoggingCombo?
    
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
        
        safePrint(
            "Inflating ValueOnlySubscriber<T\(T.self)> to \(Subscriber<T,E>.self)",
            logType: .operators,
            loggingCombo: loggingCombo
        )
        return publisher.subscriber().onCancelled {
            _ = self // Capturing self to keep subscriber alive for easier chaining.
        }
    }
    
    deinit {
        safePrint(
            "Releasing \(self) from memory.",
            logType: .lifeCycle,
            loggingCombo: loggingCombo
        )
        cancel()
    }
    
    private func executeValueCallbacks(with value: T) {
        safePrint(
            "Received \(value). -- \(self)",
            logType: .lifeCycle,
            loggingCombo: loggingCombo
        )
        valueCallbacks.forEach { (queue, action) in
            queue.async { action(value) }
        }
    }
    
    private func executeCancelCallbacks() {
        cancelCallbacks.forEach { (queue, action) in
            queue.async { action() }
        }
    }
    
    private func cancel() {
        safePrint(
            "Cancelling \(self)...",
            logType: .lifeCycle,
            loggingCombo: loggingCombo
        )
        lockQueue.async { [weak self] in
            self?.isCancelled = true
            self?.valueCallbacks.removeAll()
            self?.executeCancelCallbacks()
            self?.cancelCallbacks.removeAll()
        }
    }
    
}

extension ValueOnlySubscriber: PropagateDebuggable, CustomStringConvertible {
    
    @discardableResult public func enableLogging(
        logLevel: DebugLogLevel = .all,
        _ additionalMessage: String = "",
        _ logMethod: LoggingMethod = .debugPrint
    ) -> Self {
        self.loggingCombo = (logLevel, additionalMessage, logMethod)
        return self
    }
    
    public var description: String {
        return "ValueOnlySubscriber<\(T.self)>(\(memoryAddressStringFor(self)))"
    }
    
}

// MARK: - Subscription

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
    
}

// MARK: - Mapping and filtering

public extension ValueOnlySubscriber {
    
    /// Generates a new ValueOnlySubscriber of a different type, based on the supplied
    /// closure for mapping from one type to the other.
    @discardableResult func map<NewT>(mapping: @escaping (T) -> NewT) -> ValueOnlySubscriber<NewT> {
        let newSub = ValueOnlySubscriber<NewT>(other: self, mapBlock: mapping)
        safePrint(
            "Mapping from \(T.self) to \(NewT.self). -- \(self)",
            logType: .operators,
            loggingCombo: loggingCombo
        )
        return newSub
    }
    
    /// Generates a new ValueOnlySubscriber of a different type, based on the supplied
    /// closure for mapping from one type to the other.
    @discardableResult func compactMap<NewT>(mapping: @escaping (T) -> NewT?) -> ValueOnlySubscriber<NewT> {
        safePrint(
            "Compact mapping from \(T.self) to \(NewT.self). -- \(self)",
            logType: .operators,
            loggingCombo: loggingCombo
        )
        
        let newSub = ValueOnlySubscriber<NewT>()
        onNext { value in
            if let mappedValue = mapping(value) {
                newSub.executeValueCallbacks(with: mappedValue)
            }
        }
        onCancelled {
            newSub.cancel()
        }
        return newSub
    }
    
    /// When T is an optional type, this function generates a new subscriber that only emits
    /// the non-nil states.
    ///
    /// Example:
    /// ```
    /// let optStrings = stringSubscriber.valueOnly() // of type ValueOnlySubscriber<String?>
    /// let strings = optString.compactMap()  // Will be of type ValueOnlySubscriber<String>
    /// ```
    /// Such that if `optStrings` received `"cat", nil, "dog", nil, "banana"`, then `strings`
    /// would receive `"cat", "dog", "banana"`.
    @discardableResult func filterNil<Wrapped>() -> ValueOnlySubscriber<Wrapped> where T == Wrapped? {
        return compactMap { $0 }
    }
    
}

public extension ValueOnlySubscriber where T: Equatable {
    
    /// Only emits values that are not equal to the last emitted value.
    @discardableResult func distinctValues() -> ValueOnlySubscriber {
        let new = ValueOnlySubscriber<T>()
        
        var last: T?
        onNext { newValue in
            guard let lastValue = last else {
                new.executeValueCallbacks(with: newValue)
                last = newValue
                return
            }
            if newValue != lastValue {
                new.executeValueCallbacks(with: newValue)
                last = newValue
            }
        }
        onCancelled {
            new.cancel()
        }
        
        safePrint(
            "Removing contiguous duplicates from \(self)",
            logType: .operators,
            loggingCombo: loggingCombo
        )
        return new.onCancelled {
            _ = self
        }
    }
    
}

// MARK: - Combination -

public extension ValueOnlySubscriber {
    
    /// Combines two subscribers with different data types into one subscriber
    /// with a data type that is a tuple of the two original subscribers.
    static func combine<T2>(_ sub1: ValueOnlySubscriber<T>, _ sub2: ValueOnlySubscriber<T2>) -> ValueOnlySubscriber<(T,T2)> {
        let new = ValueOnlySubscriber<(T,T2)>()
        let tupleCreator = TwoItemTupleCreator<T,T2>()
        
        sub1.onNext {
            tupleCreator.item1 = $0
            if let tuple = tupleCreator.tuple {
                new.executeValueCallbacks(with: tuple)
            }
        }
        sub2.onNext {
            tupleCreator.item2 = $0
            if let tuple = tupleCreator.tuple {
                new.executeValueCallbacks(with: tuple)
            }
        }
        
        safePrint(
            "Combining ValueOnlySubscribers <\(T.self)> and <\(T2.self)>: -- \(memoryAddressStringFor(sub1)) & \(memoryAddressStringFor(sub2))",
            logType: .operators,
            loggingCombo: sub1.loggingCombo ?? sub2.loggingCombo // This will probably be a problem at some point.
        )
        
        return new.onCancelled {
            _ = sub1
            _ = sub2
        }
    }
    
    /// Instance method for static `Subscriber.combine(_:_:)`
    ///
    /// Combines two subscribers with different data types into one subscriber
    /// with a data type that is a tuple of the two original subscribers.
    func combineWith<T2>(_ other: ValueOnlySubscriber<T2>) -> ValueOnlySubscriber<(T,T2)> {
        return ValueOnlySubscriber.combine(self, other)
    }
    
    /// Combines three subscribers with different data types into one subscriber
    /// with a data type that is a tuple of the three original subscribers.
    static func combine<T2,T3>(
        _ sub1: ValueOnlySubscriber<T>,
        _ sub2: ValueOnlySubscriber<T2>,
        _ sub3: ValueOnlySubscriber<T3>
    ) -> ValueOnlySubscriber<(T,T2,T3)> {
        // Combine 1 + (1 + 1)
        return ValueOnlySubscriber.combine(
            sub1,
            sub2.combineWith(sub3)
        )
        .map {
            ($0.0, $0.1.0, $0.1.1)
        }
    }
    
    /// Instance method for static `Subscriber.combine(_:_:_:)`
    ///
    /// Combines three subscribers with different data types into one subscriber
    /// with a data type that is a tuple of the three original subscribers.
    func combineWith<T2,T3>(_ other1: ValueOnlySubscriber<T2>, _ other2: ValueOnlySubscriber<T3>) -> ValueOnlySubscriber<(T,T2,T3)> {
        return ValueOnlySubscriber.combine(self, other1, other2)
    }
    
    /// Combines four subscribers with different data types into one subscriber
    /// with a data type that is a tuple of the three original subscribers.
    static func combine<T2,T3,T4>(
        _ sub1: ValueOnlySubscriber<T>,
        _ sub2: ValueOnlySubscriber<T2>,
        _ sub3: ValueOnlySubscriber<T3>,
        _ sub4: ValueOnlySubscriber<T4>
    ) -> ValueOnlySubscriber<(T,T2,T3,T4)> {
        // Combine (1 + 1) + (1 + 1)
        return ValueOnlySubscriber<(T,T2)>.combine(
            sub1.combineWith(sub2),
            sub3.combineWith(sub4)
        )
        .map {
            ($0.0.0, $0.0.1, $0.1.0, $0.1.1)
        }
    }
    
    /// Instance method for static `Subscriber.combine(_:_:_:_:)`
    ///
    /// Combines four subscribers with different data types into one subscriber
    /// with a data type that is a tuple of the three original subscribers.
    func combineWith<T2,T3,T4>(
        _ other1: ValueOnlySubscriber<T2>,
        _ other2: ValueOnlySubscriber<T3>,
        _ other3: ValueOnlySubscriber<T4>
    ) -> ValueOnlySubscriber<(T,T2,T3,T4)> {
        return ValueOnlySubscriber.combine(self, other1, other2, other3)
    }
    
    /// Combines five subscribers with different data types into one subscriber
    /// with a data type that is a tuple of the three original subscribers.
    static func combine<T2,T3,T4,T5>(
        _ sub1: ValueOnlySubscriber<T>,
        _ sub2: ValueOnlySubscriber<T2>,
        _ sub3: ValueOnlySubscriber<T3>,
        _ sub4: ValueOnlySubscriber<T4>,
        _ sub5: ValueOnlySubscriber<T5>
    ) -> ValueOnlySubscriber<(T,T2,T3,T4,T5)> {
        // Combine (1 + 1) + (1 + 1 + 1)
        return ValueOnlySubscriber<(T,T2)>.combine(
            sub1.combineWith(sub2),
            sub3.combineWith(sub4, sub5)
        )
        .map {
            ($0.0.0, $0.0.1, $0.1.0, $0.1.1, $0.1.2)
        }
    }
    
    /// Instance method for static `Subscriber.combine(_:_:_:_:_:)`
    ///
    /// Combines five subscribers with different data types into one subscriber
    /// with a data type that is a tuple of the three original subscribers.
    func combineWith<T2,T3,T4,T5>(
        _ sub2: ValueOnlySubscriber<T2>,
        _ sub3: ValueOnlySubscriber<T3>,
        _ sub4: ValueOnlySubscriber<T4>,
        _ sub5: ValueOnlySubscriber<T5>
    ) -> ValueOnlySubscriber<(T,T2,T3,T4,T5)> {
        return ValueOnlySubscriber.combine(self, sub2, sub3, sub4, sub5)
    }
    
    /// Combines six subscribers with different data types into one subscriber
    /// with a data type that is a tuple of the three original subscribers.
    static func combine<T2,T3,T4,T5,T6>(
        _ sub1: ValueOnlySubscriber<T>,
        _ sub2: ValueOnlySubscriber<T2>,
        _ sub3: ValueOnlySubscriber<T3>,
        _ sub4: ValueOnlySubscriber<T4>,
        _ sub5: ValueOnlySubscriber<T5>,
        _ sub6: ValueOnlySubscriber<T6>
    ) -> ValueOnlySubscriber<(T,T2,T3,T4,T5,T6)> {
        // Combine (1 + 1 + 1) + (1 + 1 + 1)
        return ValueOnlySubscriber<(T,T2,T3)>.combine(
            sub1.combineWith(sub2, sub3),
            sub4.combineWith(sub5, sub6)
        )
        .map {
            ($0.0.0, $0.0.1, $0.0.2, $0.1.0, $0.1.1, $0.1.2)
        }
    }
    
    /// Instance method for static `Subscriber.combine(_:_:_:_:_:_:)`
    ///
    /// Combines six subscribers with different data types into one subscriber
    /// with a data type that is a tuple of the three original subscribers.
    func combineWith<T2,T3,T4,T5,T6>(
        _ sub2: ValueOnlySubscriber<T2>,
        _ sub3: ValueOnlySubscriber<T3>,
        _ sub4: ValueOnlySubscriber<T4>,
        _ sub5: ValueOnlySubscriber<T5>,
        _ sub6: ValueOnlySubscriber<T6>
    ) -> ValueOnlySubscriber<(T,T2,T3,T4,T5,T6)> {
        return ValueOnlySubscriber.combine(self, sub2, sub3, sub4, sub5, sub6)
    }
    
}
