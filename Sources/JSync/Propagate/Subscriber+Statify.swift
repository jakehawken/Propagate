//  Subscriber+Statify.swift
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
    }
    
    /// After the first `.data` state has been received,
    /// emits a tuple of the latest and the previous state
    /// on each subsequent emission.
    func scanValues() -> Subscriber<(T,T),E> {
        let publisher = Publisher<(T,T),E>()
        let state = ScanState<T>()
        onNewData { data in
            state.receiveNewState(data)
            if let scanPair = state.pair {
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
    }
    
}

class ScanState<T> {
    private(set) var penultimate: T?
    private(set) var latest: T?
    
    var pair: (T,T)? {
        guard let pen = penultimate,
              let lat = latest else {
            return nil
        }
        return (pen, lat)
    }
    
    func receiveNewState(_ value: T) {
        penultimate = latest
        latest = value
    }
}
