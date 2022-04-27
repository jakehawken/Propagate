//  Future.swift
//  Propagate
//  Created by Jacob Hawken on 4/5/22.

import Foundation

/**
 A Future is an object which represents a one-time unit of failable, asynchronous work. Generically typed `Future<T,E>` where `T` is the success type and `E` is the error type. Since futures are single-use, all completion attempts after the first will be no-ops.
*/
public class Future<T, E: Error> {
    public typealias SuccessBlock  = (T) -> Void
    public typealias ErrorBlock = (E) -> Void

    private var successBlock: SuccessBlock?
    private var errorBlock: ErrorBlock?
    private var finallyBlock: ((Result<T, E>) -> Void)?
    private var childFuture: Future?
    internal var result: Result<T, E>?
    
    internal let lockQueue = DispatchQueue(label: "com.jakehawken.jsync.future.\(NSUUID().uuidString)")

    // MARK: - PUBLIC -
    
    // MARK: public properties
    
    /// The value of the future. Will return `nil` if the future failed or is incomplete.
    public var value: T? {
        guard let result = result else {
            return nil
        }
        switch result {
        case .success(let val):
            return val
        default:
            return nil
        }
    }
    
    /// The error of the future. Will return `nil` if the future succeeded or is incomplete.
    public var error: E? {
        guard let result = result else {
            return nil
        }
        switch result {
        case .failure(let err):
            return err
        default:
            return nil
        }
    }
    
    /// Convenience property. Returns `true` if the future is completed with a success value.
    public var succeeded: Bool {
        return value != nil
    }

    /// Convenience property. Returns `true` if the future is completed with an error value.
    public var failed: Bool {
        return error != nil
    }

    /// Convenience property. Returns `true` if the future completed, regardless of whether it was a success for failure.
    public var isComplete: Bool {
        return result != nil
    }
    
    // MARK: - Public methods

    /**
    Adds a block to be executed when and if the future is resolved with a success value. Can be called multiple times to add multiple blocks. Note: Blocks will execute serially, in the order in which they were added.
    
    - Parameter callback: The block to be executed on success. Block takes a single argument, which is of the success type of the future.
    - returns: The future iself, as a `@discardableResult` to allow for chaining of callback methods.
    */
    @discardableResult public func onSuccess(_ callback: @escaping SuccessBlock) -> Future<T, E> {
        if let value = value { //If the future has already been resolved with a value. Call the block immediately.
            callback(value)
        }
        else if successBlock == nil {
            successBlock = callback
        }
        else if let child = childFuture, child.successBlock == nil {
            child.successBlock = callback
        }
        else {
            self.appendChild().onSuccess(callback)
        }
        return self
    }

    /**
    Adds a block to be executed when and if the future is rejected with an error. Can be called multiple times to add multiple blocks. Note: Blocks will execute serially, in the order in which they were added.
    
    - Parameter callback: The block to be executed on failure. Block takes a single argument, which is of the error type of the future.
    - returns: The future iself, as a `@discardableResult` to allow for chaining of callback methods.
    */
    @discardableResult public func onFailure(_ callback: @escaping ErrorBlock) -> Future<T, E> {
        if let error = self.error { //If the future has already been rejected with an error. Call the block immediately.
            callback(error)
        }
        else if self.errorBlock == nil {
            self.errorBlock = callback
        }
        else if let child = childFuture, child.errorBlock == nil {
            child.errorBlock = callback
        }
        else {
            self.appendChild().onFailure(callback)
        }
        return self
    }
    
    /**
    Adds a block to be executed when and if the future completes, regardless of success/failure state. Can be called multiple times to add multiple blocks. Note: Blocks will execute serially, in the order in which they were added.
    
    - Parameter callback: The block to be executed on completion. Block takes a single argument, which is a `Result<T,E>`.
    - returns: The future iself, as a `@discardableResult` to allow for chaining of callback methods.
    */
    @discardableResult public func finally(_ callback: @escaping (Result<T, E>) -> Void) -> Future<T, E> {
        if let result = result {
            callback(result)
        }
        else if finallyBlock == nil {
            finallyBlock = callback
        }
        else if let child = childFuture, child.finallyBlock == nil {
            child.finallyBlock = callback
        }
        else {
            appendChild().finally(callback)
        }
        return self
    }
}

internal extension Future {
    
    func resolve(_ val: T) {
        guard !isComplete else {
            return
        }
        
        let result: Result<T, E> = .success(val)
        self.result = result
        
        if let success = successBlock {
            lockQueue.sync {
                success(val)
            }
        }
        if let child = childFuture {
            lockQueue.sync {
                child.resolve(val)
            }
        }
        if let finally = finallyBlock {
            lockQueue.sync {
                finally(result)
            }
        }
    }

    func reject(_ err: E) {
        guard !isComplete else {
            return
        }
        
        let result: Result<T, E> = .failure(err)
        self.result = result
        
        if let errBlock = errorBlock {
            lockQueue.sync {
                errBlock(err)
            }
        }
        if let child = childFuture {
            lockQueue.sync {
                child.reject(err)
            }
        }
        if let finally = finallyBlock {
            lockQueue.sync {
                finally(result)
            }
        }
    }
    
    func complete(withResult result: Result<T, E>) {
        switch result {
        case .success(let value):
            resolve(value)
        case .failure(let error):
            reject(error)
        }
    }

    func appendChild() -> Future<T, E> {
        if let child = childFuture {
            return child.appendChild()
        }
        else {
            let future = Future<T, E>()
            childFuture = future
            return future
        }
    }
    
}

// MARK: - convenience constructors

public extension Future {
    /**
    Convenience constructor. Synchronously returns a pre-resolved future. Useful for testing.
    
    - Parameter value: The success value.
    - returns: A future that comes pre-resolved with the provided value.
    */
    static func of(_ value: T) -> Future<T, E> {
        let future = Future<T, E>()
        future.result = .success(value)
        return future
    }
    
    /**
    Convenience constructor. Synchronously returns a pre-rejected future. Useful for testing.
    
    - Parameter error: The failing error.
    - returns: A future that comes pre-rejected with the provided error.
    */
    static func error(_ error: E) -> Future<T, E> {
        let future = Future<T, E>()
        future.result = .failure(error)
        return future
    }
}
