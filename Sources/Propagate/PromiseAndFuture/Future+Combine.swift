//  Future+Combine.swift
//  Propagate
//  Created by Jacob Hawken on 4/26/22.

import Foundation

public extension Future {
    
    /**
     Returns a future that succeeds only when all of the supplied futures succeed, but fails as soon as any of them fail.
     
     - Parameter futures: An array of like-typed futures which must all succeed in order for the returned future to succeed.
     - returns: A future where the success value is an array of the success values from the array of promises, and the error
       is whichever error happened first.
    */
    static func merge(_ futures: [Future<T, E>]) -> Future<[T], E> {
        let promise = Promise<[T], E>()
        
        futures.forEach {
            $0.finally { (_) in
                promise.future.lockQueue.sync {
                    let results = futures.compactMap { $0.result }
                    let failures = results.compactMap { $0.failure }
                    if let firstError = failures.first {
                        promise.reject(firstError)
                    }
                    guard promise.future.isComplete == false else {
                        return
                    }
                    let successValues = results.compactMap { $0.success }
                    guard successValues.count == futures.count else {
                        return
                    }
                    promise.resolve(successValues)
                }
            }
        }
        
        return promise.future
    }
    
    /**
     Takes an array of futures, and completes with the state/value of the first future in that array to finish.
     
     - Parameter futures: An array of like-typed futures which must all succeed in order for the returned future to succeed.
     - returns: A future that completes with the state/value of which ever future in the array finishes first.
    */
    static func firstFinished(from futures: [Future]) -> Future {
        let promise = Promise<T, E>()
        
        futures.forEach {
            $0.onSuccess { (value) in
                promise.future.lockQueue.sync {
                    promise.resolve(value)
                }
            }
            .onFailure { (error) in
                promise.future.lockQueue.sync {
                    guard promise.future.isComplete == false else {
                        return
                    }
                    let failures = futures.compactMap { $0.error }
                    guard failures.count == futures.count else {
                        return
                    }
                    promise.reject(error)
                }
            }
        }
        
        return promise.future
    }
    
}

public extension Future {
    
    /// Combine two futures with a shared error type but hypothetically different success types
    /// into one future where the value type is a tuple of the two value types. Succeeds when
    /// both futures have succeeded. Fails when the first of them fails.
    static func combine<T2>(_ future1: Future<T,E>, _ future2: Future<T2,E>) -> Future<(T,T2), E> {
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
    
    /// Instance method for static `Future.combine(_:_:)`
    ///
    /// Combine two futures with a shared error type but hypothetically different success types
    /// into one future where the value type is a tuple of the two value types. Succeeds when
    /// both futures have succeeded. Fails when the first of them fails.
    func combineWith<T2>(_ other: Future<T2, E>) -> Future<(T,T2),E> {
        return Future.combine(self, other)
    }
    
    /// Combine three futures with a shared error type but hypothetically different success types
    /// into one future where the value type is a tuple of the three value types. Succeeds when
    /// all futures have succeeded. Fails when the first of them fails.
    static func combine<T2,T3>(_ future1: Future<T,E>, _ future2: Future<T2,E>, _ future3: Future<T3,E>) -> Future<(T,T2,T3), E> {
        // Combine 1 + (1 + 1)
        return Future.combine(
            future1,
            future2.combineWith(future3)
        )
        .mapValue { nestedTuple in
            (nestedTuple.0, nestedTuple.1.0, nestedTuple.1.1)
        }
    }
    
    /// Instance method for static `Future.combine(_:_:_:)`
    ///
    /// Combine three futures with a shared error type but hypothetically different success types
    /// into one future where the value type is a tuple of the three value types. Succeeds when
    /// all futures have succeeded. Fails when the first of them fails.
    func combineWith<T2,T3>(_ future2: Future<T2, E>, _ future3: Future<T3,E>) -> Future<(T,T2,T3),E> {
        return Future.combine(self, future2, future3)
    }
    
    /// Combine four futures with a shared error type but hypothetically different success types
    /// into one future where the value type is a tuple of the three value types. Succeeds when
    /// all futures have succeeded. Fails when the first of them fails.
    static func combine<T2,T3,T4>(_ future1: Future<T,E>, _ future2: Future<T2,E>, _ future3: Future<T3,E>, _ future4: Future<T4,E>) -> Future<(T,T2,T3,T4), E> {
        // Combine (1 + 1) + (1 + 1)
        return Future<(T,T2),E>.combine(
            future1.combineWith(future2),
            future3.combineWith(future4)
        )
        .mapValue { nestedTuple in
            (nestedTuple.0.0, nestedTuple.0.1, nestedTuple.1.0, nestedTuple.1.1)
        }
    }
    
    /// Instance method for static `Future.combine(_:_:_:_:)`
    ///
    /// Combine four futures with a shared error type but hypothetically different success types
    /// into one future where the value type is a tuple of the three value types. Succeeds when
    /// all futures have succeeded. Fails when the first of them fails.
    func combineWith<T2,T3,T4>(_ future2: Future<T2, E>, _ future3: Future<T3,E>, _ future4: Future<T4,E>) -> Future<(T,T2,T3,T4),E> {
        return Future.combine(self, future2, future3, future4)
    }
    
    /// Combine five futures with a shared error type but hypothetically different success types
    /// into one future where the value type is a tuple of the three value types. Succeeds when
    /// all futures have succeeded. Fails when the first of them fails.
    static func combine<T2,T3,T4,T5>(
        _ future1: Future<T,E>,
        _ future2: Future<T2,E>,
        _ future3: Future<T3,E>,
        _ future4: Future<T4,E>,
        _ future5: Future<T5,E>
    ) -> Future<(T,T2,T3,T4,T5), E> {
        // Comibe (1 + 1) + (1 + 1 + 1)
        return Future<(T,T2),E>.combine(
            future1.combineWith(future2),
            future3.combineWith(future4, future5)
        )
        .mapValue {
            ($0.0.0, $0.0.1, $0.1.0, $0.1.1, $0.1.2)
        }
    }
    
    /// Instance method for static `Future.combine(_:_:_:_:_:)`
    ///
    /// Combine five futures with a shared error type but hypothetically different success types
    /// into one future where the value type is a tuple of the three value types. Succeeds when
    /// all futures have succeeded. Fails when the first of them fails.
    func combineWith<T2,T3,T4,T5>(
        _ future2: Future<T2, E>,
        _ future3: Future<T3,E>,
        _ future4: Future<T4,E>,
        _ future5: Future<T5,E>
    ) -> Future<(T,T2,T3,T4,T5),E> {
        return Future.combine(self, future2, future3, future4, future5)
    }
    
    /// Combine six futures with a shared error type but hypothetically different success types
    /// into one future where the value type is a tuple of the three value types. Succeeds when
    /// all futures have succeeded. Fails when the first of them fails.
    static func combine<T2,T3,T4,T5,T6>(
        _ future1: Future<T,E>,
        _ future2: Future<T2,E>,
        _ future3: Future<T3,E>,
        _ future4: Future<T4,E>,
        _ future5: Future<T5,E>,
        _ future6: Future<T6,E>
    ) -> Future<(T,T2,T3,T4,T5,T6), E> {
        // Comibe (1 + 1 + 1) + (1 + 1 + 1)
        return Future<(T,T2,T3),E>.combine(
            future1.combineWith(future2, future3),
            future4.combineWith(future5, future6)
        )
        .mapValue {
            ($0.0.0, $0.0.1, $0.0.2, $0.1.0, $0.1.1, $0.1.2)
        }
    }
    
    /// Instance method for static `Future.combine(_:_:_:_:_:_:)`
    ///
    /// Combine six futures with a shared error type but hypothetically different success types
    /// into one future where the value type is a tuple of the three value types. Succeeds when
    /// all futures have succeeded. Fails when the first of them fails.
    func combineWith<T2,T3,T4,T5,T6>(
        _ future2: Future<T2, E>,
        _ future3: Future<T3,E>,
        _ future4: Future<T4,E>,
        _ future5: Future<T5,E>,
        _ future6: Future<T6,E>
    ) -> Future<(T,T2,T3,T4,T5,T6),E> {
        return Future.combine(self, future2, future3, future4, future5, future6)
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
