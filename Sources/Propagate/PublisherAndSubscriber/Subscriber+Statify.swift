//  Subscriber+Statify.swift
//  Propagate
//  Created by Jacob Hawken on 4/17/22.

import Foundation

public extension Subscriber {
    
    /// Generates a new subscriber that synchronously
    /// emits the last state (if any) when subscribed to.
    func stateful() -> Subscriber<T,E> {
        let publisher = StatefulPublisher<T,E>()
        
        subscribe { state in
            publisher.publishNewState(state)
        }
        
        return publisher.subscriber()
            .onCancelled {
                _ = self // Capturing self to keep subscriber alive for easier chaining.
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
