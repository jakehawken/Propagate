//  Promise.swift
//  Propagate
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
