//  Subscriber+Combine.swift
//  Propagate
//  Created by Jacob Hawken on 4/26/22.

import Foundation

public extension Subscriber {
    
    /// Combines two subscribers with different data types into one subscriber
    /// with a data type that is a tuple of the two original subscribers.
    static func combine<T2>(_ sub1: Subscriber<T,E>, _ sub2: Subscriber<T2,E>) -> Subscriber<(T,T2),E> {
        let publisher = Publisher<(T,T2),E>()
        let tupleCreator = TwoItemTupleCreator<T,T2>()
        
        sub1.onNewData {
            tupleCreator.item1 = $0
            if let tuple = tupleCreator.tuple {
                publisher.publish(tuple)
            }
        }
        sub2.onNewData {
            tupleCreator.item2 = $0
            if let tuple = tupleCreator.tuple {
                publisher.publish(tuple)
            }
        }
        
        return publisher.subscriber()
    }
    
    func combineWith<T2>(_ other: Subscriber<T2,E>) -> Subscriber<(T,T2),E> {
        return Subscriber.combine(self, other)
    }
    
    /// Combines three subscribers with different data types into one subscriber
    /// with a data type that is a tuple of the three original subscribers.
    static func combine<T2,T3>(
        _ sub1: Subscriber<T,E>,
        _ sub2: Subscriber<T2,E>,
        _ sub3: Subscriber<T3,E>
    ) -> Subscriber<(T,T2,T3),E> {
        // Combine 1 + (1 + 1)
        return Subscriber.combine(
            sub1,
            Subscriber<T2,E>.combine(sub2,sub3)
        )
        .mapValues {
            ($0.0, $0.1.0, $0.1.1)
        }
    }
    
    func combineWith<T2,T3>(_ other1: Subscriber<T2,E>, _ other2: Subscriber<T3,E>) -> Subscriber<(T,T2,T3),E> {
        return Subscriber.combine(self, other1, other2)
    }
    
    /// Combines three subscribers with different data types into one subscriber
    /// with a data type that is a tuple of the three original subscribers.
    static func combine<T2,T3,T4>(
        _ sub1: Subscriber<T,E>,
        _ sub2: Subscriber<T2,E>,
        _ sub3: Subscriber<T3,E>,
        _ sub4: Subscriber<T4,E>
    ) -> Subscriber<(T,T2,T3,T4),E> {
        // Combine (1 + 1) + (1 + 1)
        return Subscriber<(T,T2),E>.combine(
            Subscriber.combine(sub1, sub2),
            Subscriber<T3,E>.combine(sub3, sub4)
        )
        .mapValues {
            ($0.0.0, $0.0.1, $0.1.0, $0.1.1)
        }
    }
    
    func combineWith<T2,T3,T4>(_ other1: Subscriber<T2,E>, _ other2: Subscriber<T3,E>, _ other3: Subscriber<T4,E>) -> Subscriber<(T,T2,T3,T4),E> {
        return Subscriber.combine(self, other1, other2, other3)
    }
    
}

