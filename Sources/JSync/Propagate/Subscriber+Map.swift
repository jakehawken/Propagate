//  Subscriber+Map.swift
//  JSync
//  Created by Jacob Hawken on 3/8/22.
//  Copyright © 2022 Jake Hawken. All rights reserved.

import Foundation

// MARK: - Mapping

public extension Subscriber {
    
    func mapState<NewT, NewE: Error>(
        _ transform: @escaping (StreamState<T,E>) -> StreamState<NewT, NewE>
    ) -> Subscriber<NewT, NewE> {
        let newSubscriber = Subscriber<NewT,NewE>(
            canceller: Canceller(cancelAction: { _ in
                _ = self // self reference to keep the original subscriber alive
            })
        )
        
        subscribe { oldState in
            let newState = transform(oldState)
            newSubscriber.receive(newState)
        }
        
        safePrint(
            "Mapping \(self) to \(newSubscriber)",
            logType: .operators
        )
        return newSubscriber
    }
    
    func mapValues<NewT>(_ transform: @escaping (T) -> NewT) -> Subscriber<NewT, E> {
        return mapState { oldState in
            switch oldState {
            case .data(let data):
                let transformed = transform(data)
                safePrint(
                    "Mapped \(T.self)(\(oldState)) to \(NewT.self)(\(transformed))",
                    logType: .operators
                )
                return .data(transformed)
            case .error(let error):
                return .error(error)
            case .cancelled:
                return .cancelled
            }
        }
    }
    
    func mapErrors<NewE: Error>(_ transform: @escaping (E) -> NewE) -> Subscriber<T, NewE> {
        return mapState { oldState in
            switch oldState {
            case .data(let data):
                return .data(data)
            case .error(let error):
                let transformed = transform(error)
                safePrint(
                    "Mapped \(E.self)(\(oldState)) to \(NewE.self)(\(transformed))",
                    logType: .operators
                )
                return .error(transformed)
            case .cancelled:
                return .cancelled
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
    }
    
}
