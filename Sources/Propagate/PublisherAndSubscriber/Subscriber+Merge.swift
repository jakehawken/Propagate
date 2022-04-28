//  Subscriber+Merge.swift
//  Propagate
//  Created by Jacob Hawken on 4/27/22.

import Foundation

public extension Subscriber {
    
    /// Pipes the outputs of an array of Subscribers of the same
    /// generic types to a single subscriber of the same types.
    /// New `.data` and `.error` state sent to any of the source
    /// subscribers is sent to the merged subscriber.
    ///
    /// Note: The `.cancelled` state on the returned subscriber will
    /// only be triggered if all of the source subscribers have
    /// been cancelled.
    static func merge(_ subscribers: [Subscriber]) -> Subscriber {
        let publisher = Publisher<T,E>()
        
        subscribers.forEach { subscriber in
            subscriber.onNewData { data in
                publisher.publish(data)
            }
            subscriber.onError { error in
                publisher.publish(error)
            }
            subscriber.onCancelled {
                if subscribers.allSatisfy({ $0.isCancelled }) {
                    publisher.cancelAll()
                }
            }
        }
        
        return publisher.subscriber()
    }
    
    /// Pipes the outputs of a variadic array of Subscribers of the
    /// same generic types to a single subscriber of the same types.
    /// New `.data` and `.error` state sent to any of the source
    /// subscribers is sent to the merged subscriber.
    ///
    /// Note: The `.cancelled` state on the returned subscriber will
    /// only be triggered if all of the source subscribers have
    /// been cancelled.
    static func merge(_ subscribers: Subscriber...) -> Subscriber {
        merge(subscribers)
    }
    
    /// Pipes the output of the subscriber, along with the outputs
    /// of an array of Subscribers of the same generic types to a
    /// single subscriber of the same types. New `.data` and
    /// `.error` state sent to any of the source subscribers is
    /// sent to the merged subscriber.
    ///
    /// Note: The `.cancelled` state on the returned subscriber will
    /// only be triggered if all of the source subscribers have
    /// been cancelled.
    func mergeWith(_ subscribers: [Subscriber]) -> Subscriber {
        let subsToMerge = [self] + subscribers
        return Subscriber.merge(subsToMerge)
    }
    
    /// Pipes the output of the subscriber, along with the outputs
    /// of a variadic array of Subscribers of the same generic
    /// types to a single subscriber of the same types. New `.data`
    /// and `.error` state sent to any of the source subscribers is
    /// sent to the merged subscriber.
    ///
    /// Note: The `.cancelled` state on the returned subscriber will
    /// only be triggered if all of the source subscribers have
    /// been cancelled.
    func mergeWith(_ subscribers: Subscriber...) -> Subscriber {
        return mergeWith(subscribers)
    }
    
}
