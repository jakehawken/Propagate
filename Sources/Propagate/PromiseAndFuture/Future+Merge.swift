//  Future+Merge.swift
//  Propagate
//  Created by Jacob Hawken on 4/26/22.

import Foundation

public extension Future {
    
    // MARK: - combine specific numbers of futures
    
    /// Combine two futures with a shared error type but hypothetically different success types
    /// into one future where the value type is a tuple of the two value types. Succeeds when
    /// both futures have succeeded. Fails when the first of them fails.
    static func merge<T2>(_ future1: Future<T,E>, _ future2: Future<T2,E>) -> Future<(T,T2), E> {
        let promise = Promise<(T,T2), E>()
        
        let tupleCreator = TwoItemTupleCreator<T,T2>()
        
        future1.onSuccess {
            tupleCreator.item1 = $0
            if let tuple = tupleCreator.tuple {
                promise.resolve(tuple)
            }
        }
        .onFailure {
            promise.reject($0)
        }
        
        future2.onSuccess {
            tupleCreator.item2 = $0
            if let tuple = tupleCreator.tuple {
                promise.resolve(tuple)
            }
        }
        .onFailure {
            promise.reject($0)
        }
        
        return promise.future
    }
    
    /// Combine three futures with a shared error type but hypothetically different success types
    /// into one future where the value type is a tuple of the three value types. Succeeds when
    /// all futures have succeeded. Fails when the first of them fails.
    static func merge<T2,T3>(_ future1: Future<T,E>, _ future2: Future<T2,E>, _ future3: Future<T3,E>) -> Future<(T,T2,T3), E> {
        return Future.merge(
            future1,
            Future<T2,E>.merge(future2, future3)
        )
        .mapValue { nestedTuple in
            (nestedTuple.0, nestedTuple.1.0, nestedTuple.1.1)
        }
    }
    
    /// Combine four futures with a shared error type but hypothetically different success types
    /// into one future where the value type is a tuple of the three value types. Succeeds when
    /// all futures have succeeded. Fails when the first of them fails.
    static func merge<T2,T3,T4>(_ future1: Future<T,E>, _ future2: Future<T2,E>, _ future3: Future<T3,E>, _ future4: Future<T4,E>) -> Future<(T,T2,T3,T4), E> {
        return Future<(T,T2),E>.merge(
            Future.merge(future1, future2),
            Future<T3,E>.merge(future3, future4)
        )
        .mapValue { nestedTuple in
            (nestedTuple.0.0, nestedTuple.0.1, nestedTuple.1.0, nestedTuple.1.1)
        }
    }
    
}

class TwoItemTupleCreator<A,B> {
    var item1: A?
    var item2: B?
    
    var tuple: (A,B)? {
        guard let a = item1,
              let b = item2 else {
            return nil
        }
        return (a,b)
    }
}
