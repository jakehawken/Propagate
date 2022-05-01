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
    
    /// Instance method for static `Subscriber.combine(_:_:)`
    ///
    /// Combines two subscribers with different data types into one subscriber
    /// with a data type that is a tuple of the two original subscribers.
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
            sub2.combineWith(sub3)
        )
        .mapValues {
            ($0.0, $0.1.0, $0.1.1)
        }
    }
    
    /// Instance method for static `Subscriber.combine(_:_:_:)`
    ///
    /// Combines three subscribers with different data types into one subscriber
    /// with a data type that is a tuple of the three original subscribers.
    func combineWith<T2,T3>(_ other1: Subscriber<T2,E>, _ other2: Subscriber<T3,E>) -> Subscriber<(T,T2,T3),E> {
        return Subscriber.combine(self, other1, other2)
    }
    
    /// Combines four subscribers with different data types into one subscriber
    /// with a data type that is a tuple of the three original subscribers.
    static func combine<T2,T3,T4>(
        _ sub1: Subscriber<T,E>,
        _ sub2: Subscriber<T2,E>,
        _ sub3: Subscriber<T3,E>,
        _ sub4: Subscriber<T4,E>
    ) -> Subscriber<(T,T2,T3,T4),E> {
        // Combine (1 + 1) + (1 + 1)
        return Subscriber<(T,T2),E>.combine(
            sub1.combineWith(sub2),
            sub3.combineWith(sub4)
        )
        .mapValues {
            ($0.0.0, $0.0.1, $0.1.0, $0.1.1)
        }
    }
    
    /// Instance method for static `Subscriber.combine(_:_:_:_:)`
    ///
    /// Combines four subscribers with different data types into one subscriber
    /// with a data type that is a tuple of the three original subscribers.
    func combineWith<T2,T3,T4>(
        _ other1: Subscriber<T2,E>,
        _ other2: Subscriber<T3,E>,
        _ other3: Subscriber<T4,E>
    ) -> Subscriber<(T,T2,T3,T4),E> {
        return Subscriber.combine(self, other1, other2, other3)
    }
    
    /// Combines five subscribers with different data types into one subscriber
    /// with a data type that is a tuple of the three original subscribers.
    static func combine<T2,T3,T4,T5>(
        _ sub1: Subscriber<T,E>,
        _ sub2: Subscriber<T2,E>,
        _ sub3: Subscriber<T3,E>,
        _ sub4: Subscriber<T4,E>,
        _ sub5: Subscriber<T5,E>
    ) -> Subscriber<(T,T2,T3,T4,T5),E> {
        // Combine (1 + 1) + (1 + 1 + 1)
        return Subscriber<(T,T2),E>.combine(
            sub1.combineWith(sub2),
            sub3.combineWith(sub4, sub5)
        )
        .mapValues {
            ($0.0.0, $0.0.1, $0.1.0, $0.1.1, $0.1.2)
        }
    }
    
    /// Instance method for static `Subscriber.combine(_:_:_:_:_:)`
    ///
    /// Combines five subscribers with different data types into one subscriber
    /// with a data type that is a tuple of the three original subscribers.
    func combineWith<T2,T3,T4,T5>(
        _ sub2: Subscriber<T2,E>,
        _ sub3: Subscriber<T3,E>,
        _ sub4: Subscriber<T4,E>,
        _ sub5: Subscriber<T5,E>
    ) -> Subscriber<(T,T2,T3,T4,T5),E> {
        return Subscriber.combine(self, sub2, sub3, sub4, sub5)
    }
    
    /// Combines six subscribers with different data types into one subscriber
    /// with a data type that is a tuple of the three original subscribers.
    static func combine<T2,T3,T4,T5,T6>(
        _ sub1: Subscriber<T,E>,
        _ sub2: Subscriber<T2,E>,
        _ sub3: Subscriber<T3,E>,
        _ sub4: Subscriber<T4,E>,
        _ sub5: Subscriber<T5,E>,
        _ sub6: Subscriber<T6,E>
    ) -> Subscriber<(T,T2,T3,T4,T5,T6),E> {
        // Combine (1 + 1 + 1) + (1 + 1 + 1)
        return Subscriber<(T,T2,T3),E>.combine(
            sub1.combineWith(sub2, sub3),
            sub4.combineWith(sub5, sub6)
        )
        .mapValues {
            ($0.0.0, $0.0.1, $0.0.2, $0.1.0, $0.1.1, $0.1.2)
        }
    }
    
    /// Instance method for static `Subscriber.combine(_:_:_:_:_:_:)`
    ///
    /// Combines six subscribers with different data types into one subscriber
    /// with a data type that is a tuple of the three original subscribers.
    func combineWith<T2,T3,T4,T5,T6>(
        _ sub2: Subscriber<T2,E>,
        _ sub3: Subscriber<T3,E>,
        _ sub4: Subscriber<T4,E>,
        _ sub5: Subscriber<T5,E>,
        _ sub6: Subscriber<T6,E>
    ) -> Subscriber<(T,T2,T3,T4,T5,T6),E> {
        return Subscriber.combine(self, sub2, sub3, sub4, sub5, sub6)
    }
    
}

