//  Subscriber+Map.swift
//  Propagate
//  Created by Jacob Hawken on 3/8/22.
//  Copyright © 2022 Jake Hawken. All rights reserved.

import Foundation

// MARK: - Mapping

public extension Subscriber {
    
    /// Using the supplied transform, maps the states received by this
    /// subscriber to states of a different type on a new subscriber.
    func mapStates<NewT, NewE: Error>(
        _ transform: @escaping (StreamState<T,E>) -> StreamState<NewT, NewE>
    ) -> Subscriber<NewT, NewE> {
        let newPublisher = Publisher<NewT,NewE>()
        
        subscribe { oldState in
            let newState = transform(oldState)
            newPublisher.publishNewState(newState)
        }
        
        let newSubscriber = newPublisher.subscriber()
        
        safePrint(
            "Mapping states from StreamState<\(T.self),\(E.self)> to StreamState<\(NewT.self),\(NewE.self)>",
            logType: .operators
        )
        return newSubscriber
            .onCancelled {
                _ = self // Capturing self to keep subscriber alive for easier chaining.
            }
    }
    
    /// Using the supplied transform, maps the values from `.data` states received by
    /// this subscriber to `.data` values of a different type on a new subscriber.
    /// Other states (`.error` and `.cancelled`) pass through like normal.
    func mapValues<NewT>(_ transform: @escaping (T) -> NewT) -> Subscriber<NewT, E> {
        safePrint("Mapping values from \(T.self) to \(NewT.self)", logType: .operators)
        return mapStates { oldState in
            switch oldState {
            case .data(let data):
                let transformed = transform(data)
                return .data(transformed)
            case .error(let error):
                return .error(error)
            case .cancelled:
                return .cancelled
            }
        }
    }
    
    /// Allows `.data` value to conditionally trigger the `.error` state. Used for when only a constrained range of data values are valid.
    func splitMapValues<NewT>(_ transform: @escaping (T) -> StreamState<NewT, E>) -> Subscriber<NewT, E> {
        return mapStates { state -> StreamState<NewT, E> in
            switch state {
            case .cancelled:
                return .cancelled
            case .error(let error):
                return .error(error)
            case .data(let value):
                return transform(value)
            }
        }
    }
    
    /// Using the supplied transform, maps the errors from `.error` states received by
    /// this subscriber to `.error` errors of a different type on a new subscriber.
    /// Other states (`.data` and `.cancelled`) pass through like normal.
    func mapErrors<NewE: Error>(_ transform: @escaping (E) -> NewE) -> Subscriber<T, NewE> {
        safePrint("Mapping errors from \(E.self) to \(NewE.self).", logType: .operators)
        return mapStates { oldState in
            switch oldState {
            case .data(let data):
                return .data(data)
            case .error(let error):
                let transformed = transform(error)
                return .error(transformed)
            case .cancelled:
                return .cancelled
            }
        }
    }
    
    /// Allows `.error` state to conditionally trigger the `.data` state. Used for when some error states on a subscriber represent success states in a new context.
    func splitMapErrors<NewE>(_ transform: @escaping (E) -> StreamState<T, NewE>) -> Subscriber<T, NewE> {
        return mapStates { state -> StreamState<T, NewE> in
            switch state {
            case .cancelled:
                return .cancelled
            case .error(let error):
                return transform(error)
            case .data(let value):
                return .data(value)
            }
        }
    }
    
}

public extension Subscriber {
    
    /// Performs the mapping transformation to each state emitted. If the
    /// mapping returns nil, no state at all is emitted on the new subscriber.
    func compactMapStates<NewT, NewE: Error>(_ mapping: @escaping (Subscriber<T,E>.State) -> Subscriber<NewT,NewE>.State?) -> Subscriber<NewT,NewE> {
        let publisher = Publisher<NewT,NewE>()
        
        subscribe { state in
            if let mappedState = mapping(state) {
                publisher.publishNewState(mappedState)
            }
        }
        
        return publisher.subscriber()
            .onCancelled {
                _ = self // Capturing self to keep subscriber alive for easier chaining.
            }
    }
    
    /// Performs the mapping transformation to each `.data` state. If the
    /// mapping returns nil, no value is emitted on the new subscriber.
    /// However, `.error` and `.cancelled` states pass through normally.
    func compactMapValues<NewT>(_ mapping: @escaping (T) -> NewT?) -> Subscriber<NewT,E> {
        let publisher = Publisher<NewT,E>()
        
        subscribe { state in
            switch state {
            case .error(let error):
                publisher.publish(error)
            case .cancelled:
                publisher.cancelAll()
            case .data(let value):
                if let mappedvalue = mapping(value) {
                    publisher.publish(mappedvalue)
                }
            }
        }
        
        return publisher.subscriber()
            .onCancelled {
                _ = self // Capturing self to keep subscriber alive for easier chaining.
            }
    }
    
    /// Performs the mapping transformation to each `.error` state. If the
    /// mapping returns nil, no error is emitted on the new subscriber.
    /// However, `.data` and `.cancelled` states pass through normally.
    func compactMapErrors<NewE: Error>(_ mapping: @escaping (E) -> NewE?) -> Subscriber<T,NewE> {
        let publisher = Publisher<T,NewE>()
        
        subscribe { state in
            switch state {
            case .error(let error):
                if let mappedError = mapping(error) {
                    publisher.publish(mappedError)
                }
            case .cancelled:
                publisher.cancelAll()
            case .data(let value):
                publisher.publish(value)
            }
        }
        
        return publisher.subscriber()
            .onCancelled {
                _ = self // Capturing self to keep subscriber alive for easier chaining.
            }
    }
    
}
