//  Subscriber+Filter.swift
//  Created by Jacob Hawken on 4/17/22.

import Foundation

// MARK: - Filter

public extension Subscriber {
    
    /// Filters out `.data` states that do not match a given criteria.
    @discardableResult func filterValues(_ isIncluded: @escaping (T) -> Bool) -> Subscriber<T,E> {
        let publisher = Publisher<T,E>()
        
        subscribe { state in
            switch state {
            case .error, .cancelled:
                publisher.publishNewState(state)
            case .data(let value):
                if isIncluded(value) {
                    publisher.publishNewState(state)
                }
            }
        }
        
        return publisher.subscriber()
    }
    
    /// Filters out all states that do not match a given criteria.
    @discardableResult func filterStates(_ isIncluded: @escaping (State) -> Bool) -> Subscriber<T,E> {
        let publisher = Publisher<T,E>()
        
        subscribe { state in
            guard isIncluded(state) else {
                return
            }
            publisher.publishNewState(state)
        }
        
        return publisher.subscriber()
    }
    
}

public extension Subscriber where T: Equatable {
    
    /// New `.data` states are only emitted if:
    /// A) the last state was not `.data`, or
    /// B) the last state's data did not have the same value.
    @discardableResult func distinctValues() -> Subscriber<T,E> {
        let publisher = StatefulPublisher<T,E>()
        
        subscribe { state in
            guard let lastState = publisher.lastState else {
                publisher.publishNewState(state)
                return
            }
            switch (state, lastState) {
            case (.data(let new), .data(let last)):
                if new != last {
                    publisher.publishNewState(state)
                }
            case (.cancelled, .cancelled):
                break
            default:
                publisher.publishNewState(state)
            }
        }
        
        return publisher.subscriber()
    }
    
}

// MARK: - Distinct

public extension Subscriber where T: Equatable, E: Equatable {
    
    /// Emits only if the state differs from the last state.
    @discardableResult func distinctStates() -> Subscriber<T,E> {
        let publisher = StatefulPublisher<T,E>()
        
        subscribe { state in
            guard let lastState = publisher.lastState else {
                publisher.publishNewState(state)
                return
            }
            switch (state, lastState) {
            case (.data(let new), .data(let last)):
                if new != last {
                    publisher.publishNewState(state)
                }
            case (.error(let new), .error(let last)):
                if new != last {
                    publisher.publishNewState(state)
                }
            case (.cancelled, .cancelled):
                break
            default:
                publisher.publishNewState(state)
            }
        }
        
        return publisher.subscriber()
    }
    
}
