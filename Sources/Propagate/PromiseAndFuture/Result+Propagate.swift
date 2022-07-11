//  Result.swift
//  Propagate
//  Created by Jacob Hawken on 10/7/17.
//  Copyright © 2017 CocoaPods. All rights reserved.

import Foundation

//swiftlint:disable line_length
public extension Result {
    
    typealias SuccessBlock = (Success) -> Void
    typealias ErrorBlock = (Failure) -> Void
    
    /**
    Convenience block for adding functional-style chaining to `Result`.
    
    - Parameter successBlock: The block to be executed on success. Block takes a single argument, which is of the `Success` type of the result. Executes if success case. Does not execute if failure case.
    - returns: The future iself, as a `@discardableResult` to allow for chaining.
    */
    @discardableResult func onSuccess(_ successBlock: SuccessBlock) -> Result<Success, Failure> {
        switch self {
        case .success(let value):
            successBlock(value)
        default:
            break
        }
        return self
    }
    
    /**
    Convenience block for adding functional-style chaining to `Result`.
    
    - Parameter errorBlock: The block to be executed on failure. Block takes a single argument, which is of the `Error` type of the result. Executes if failure case. Does not execute if success case.
    - returns: The future iself, as a `@discardableResult` to allow for chaining.
    */
    @discardableResult func onError(_ errorBlock: ErrorBlock) -> Result<Success, Failure> {
        switch self {
        case .failure(let error):
            errorBlock(error)
        default:
            break
        }
        return self
    }
    
    /// Convenience property for converting the state of result into an optional `Success`. Returns nil in failure case.
    var success: Success? {
        switch self {
        case .success(let value):
            return value
        case .failure:
            return nil
        }
    }
    
    /// Convenience property for converting the state of result into an optional `Failure`. Returns nil in success case.
    var failure: Failure? {
        switch self {
        case .success:
            return nil
        case .failure(let value):
            return value
        }
    }
    
}
