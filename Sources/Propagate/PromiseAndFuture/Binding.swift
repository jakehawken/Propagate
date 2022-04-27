//  Binding.swift
//  Propagate
//  Created by Jake Hawken on 11/27/19.
//  Copyright © 2019 Jacob Hawken. All rights reserved.

import Foundation

// MARK: - Binding

public extension Promise {
    
    /// Convenience method for completing a promise based on the result of a given
    /// future with the same generic types.
    ///
    /// - Parameter future: A future with the same success and error types as the
    ///  promise. On completion of the future, the corresponding completion state
    ///  will be triggered on the promise.
    func completeOn(future: Future<T, E>) {
        future.finally(complete(withResult:))
    }
    
}

public extension Future {
    
    /// The inverse of `completeOn(future:)`. Convenience method for completing
    /// a promise based on the result of a given future with the same generic types.
    ///
    /// - Parameter future: A future with the same success and error types as the
    /// promise. On completion of the future, the corresponding completion state
    /// will be triggered on the promise.
    ///
    /// - returns: The future itself, as a @discardableResult, to allow for chaining.
    @discardableResult func bindTo(_ promise: Promise<T,E>) -> Future<T,E> {
        return finally {
            promise.complete(withResult: $0)
        }
    }
    
}
