//  Promise.swift
//  JSync
//  Created by Jacob Hawken on 10/7/17.
//  Copyright © 2017 CocoaPods. All rights reserved.

import Foundation

//swiftlint:disable line_length

/**
 Promise is the object responsible for creating and completing a future. Generically typed `Promise<T,E>`,
 where `T` is the success type and `E` is the error type.
 
 Promises/Futures are for single-use events and can only be completed (resolved/rejected) once. Subsequent
 completion attempts will be no-ops.
 
 In typical use, the promise is not revealed to the consumer of the future. A method returns a future and
 privately completes the promise on completion of the asynchronous work.
*/
public class Promise<T, E: Error> {
    
    /// The generated future, which only this promise can resolve.
    public let future = Future<T, E>()
    
    public init() {}
    
    /**
    Convenience initializer. Synchronously returns a promise with a pre-resolved future. Useful for testing.
    
    - Parameter value: The success value.
    - returns: A promise with a future that comes pre-resolved with the provided value.
    */
    public convenience init(value: T) {
        self.init()
        resolve(value)
    }
    
    /**
    Convenience initializer. Synchronously returns a promise with a pre-rejected future. Useful for testing.
    
    - Parameter error: The failing error.
    - returns: A promise with a future that comes pre-rejected with the provided error.
    */
    public convenience init(error: E) {
        self.init()
        reject(error)
    }

    /**
     Triggers the success state of the associated future and locks the future as completed.
     
     - Parameter val: The success value.
     */
    public func resolve(_ val: T) {
        future.resolve(val)
    }

    /**
    Triggers the failure state of the associated future and locks the future as completed.
    
    - Parameter err: The error value.
    */
    public func reject(_ err: E) {
        future.reject(err)
    }
    
    /**
    Triggers a completed state on the associated future, corresponding to the `.success` or `.failure` state of the result,
    and locks the future as completed.
    
    - Parameter result: A result of type `Result<T,E>`, where `T` and `E` correspond to the value and error types of the promise.
    */
    public func complete(withResult result: Result<T, E>) {
        future.complete(withResult: result)
    }
}

// MARK: - combination

public extension Future {
    
    /**
     Returns a future that succeeds only when all of the supplied futures succeed, but fails as soon as any of them fail.
     
     - Parameter futures: An array of like-typed futures which must all succeed in order for the returned future to succeed.
     - returns: A future where the success value is an array of the success values from the array of promises, and the error
       is whichever error happened first.
    */
    static func zip(_ futures: [Future<T, E>]) -> Future<[T], E> {
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
