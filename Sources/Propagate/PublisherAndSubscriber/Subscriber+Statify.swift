//  Subscriber+Statify.swift
//  Propagate
//  Created by Jacob Hawken on 4/17/22.

import Foundation

public extension Subscriber {
    
    /// Generates a new subscriber that synchronously
    /// emits the last state (if any) when subscribed to.
    func stateful() -> Subscriber<T,E> {
        boundStatefulPublisher()
            .subscriber()
            .onCancelled {
                // Capturing self to keep subscriber alive for easier chaining.
                _ = self
            }
    }
    
    func startWith(_ value: T) -> Subscriber<T,E> {
        let publisher = boundStatefulPublisher()
        publisher.publish(value)
        return publisher.subscriber()
            .onCancelled {
                // Capturing self to keep subscriber alive for easier chaining.
                _ = self
            }
    }
    
    /// Generates a subscriber that only ever receives a single value, and which will
    /// synchronously emit when a new subscrition to that subscriber is added.
    static func of(_ value: T) -> Subscriber {
        let publisher = StatefulPublisher<T,E>()
        publisher.publish(value)
        return publisher.subscriber()
            .onCancelled {
                // Capturing publisher so that the last received state can be retained.
                _ = publisher
            }
    }
    
    /// Generates a subscriber that only ever receives a single error, and which will
    /// synchronously emit when a new subscrition to that subscriber is added.
    static func of(_ error: E) -> Subscriber {
        let publisher = StatefulPublisher<T,E>()
        publisher.publish(error)
        return publisher.subscriber()
            .onCancelled {
                // Capturing publisher so that the last received state can be retained.
                _ = publisher
            }
    }
    
    /// After the first n `.data` states has been received, emits
    /// an array of the last n states on each subsequent emission.
    ///
    /// This buffer of `.data` states will be maintained even if a
    /// `.error` state is received between any of them.
    ///
    /// - Parameter scanSize: The number of recent items to include
    /// in the buffer. A value less than 1 will result in a
    /// subscriber that never emits on `.data` states.
    ///
    /// - returns: A subscriber where the data type is an array of
    /// the element type of the subscriber being scanned, i.e.
    /// `Subscriber<T,E>` becomes a `Subscriber<[T],E>`.
    func scanValues(_ scanSize: Int) -> Subscriber<[T],E> {
        let publisher = Publisher<[T],E>()
        let state = ScanState(
            scanSize: scanSize,
            subscriber: self
        )
        
        onNewData { data in
            state.receiveNewState(data)
            if let scanPair = state.scan {
                publisher.publish(scanPair)
            }
        }
        onError { error in
            publisher.publish(error)
        }
        onCancelled {
            publisher.cancelAll()
        }
        
        return publisher.subscriber()
        /// Note: Does not need a `.onCancelled { _ = self }` operation appended
        /// like other operators do because it already retains a reference to the
        /// subscriber, by nature of its implementation.
    }
    
}

class ScanState<T,E: Error> {
    
    private(set) var values = [T]()
    
    let scanSize: Int
    let subscriber: Subscriber<T,E>
    
    /// Values less than 1 will never return.
    init(scanSize: Int, subscriber: Subscriber<T,E>) {
        self.scanSize = scanSize
        self.subscriber = subscriber
    }
    
    func receiveNewState(_ value: T) {
        values.append(value)
    }
    
    var scan: [T]? {
        guard scanSize > 0 else {
            return nil
        }
        guard values.count >= scanSize else {
            return nil
        }
        return values.suffix(scanSize)
    }
    
}

private extension Subscriber {
    
    func boundStatefulPublisher() -> StatefulPublisher<T,E> {
        let publisher = StatefulPublisher<T,E>()
        bindTo(publisher)
        return publisher
    }
    
}
