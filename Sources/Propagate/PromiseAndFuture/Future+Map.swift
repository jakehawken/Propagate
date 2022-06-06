//  Future+Map.swift
//  Propagate
//  Created by Jacob Hawken on 4/25/22.

import Foundation

public extension Future {
    
    /**
    Operator. Generates a new Future with potentially different success and/or error types.
     
     Example:
     ```
     let myFuture = Promise<Int, MyIntError>.future
     let myNewFuture = myFuture.mapResult { (result) -> Result<String, MyStringError>
        switch result {
        case .success(let firstValue):
            if firstValue < 5 {
                return .success("\(firstValue)")
            }
            else {
                return .failure(.couldntMakeString)
            }
        case .failure(let firstError):
            return .failure(.couldntGetInt)
        }
     }
     // Returns a future of type Future<String, MyStringError>
     ```
    
    - Parameter mapBlock: The mapping block, which is executed on completion of the future. The block takes a single argument,
     which is of the `Result<T,E>` of the original future, and returns a `Result` with a different success and/or error type.
    - returns: The new future, as a `@discardableResult` to allow for the chaining of mutation/callback methods.
    */
    @discardableResult func mapResult<NewT, NewE: Error>(_ mapBlock:@escaping (Result<T, E>) -> (Result<NewT, NewE>)) -> Future<NewT, NewE> {
        let promise = Promise<NewT, NewE>()
        
        finally { (result) in
            let newResult = mapBlock(result)
            promise.complete(withResult: newResult)
        }
        
        return promise.future
    }
    
    /**
    Operator. Generates a new Future with a different success type, but the same error type. If the first future fails,
    the error will be passed through to the new future. Ideal when there is not a new possible failure stage introduced by the mutation.
     
     Example:
     ```
     let myFuture = Promise<Int, MyIntError>.future
     let myNewFuture = myFuture.mapValue { (firstValue)
        return "\(firstValue)"
     }
     // Returns a future of type Future<String, MyIntError>
     ```
    
    - Parameter mapBlock: The mapping block, which is executed on completion of the future. The block takes a single argument,
      which is of the success type `T` of the original future, and returns a value of the success type `NewValue` of the new future.
    - returns: The new future, as a `@discardableResult` to allow for the chaining of mutation/callback methods.
    */
    @discardableResult func mapValue<NewValue>(_ mapBlock:@escaping (T) -> (NewValue)) -> Future<NewValue, E> {
        let promise = Promise<NewValue, E>()
        
        onSuccess { (value) in
            let newVal = mapBlock(value)
            promise.resolve(newVal)
        }
        onFailure { (error) in
            promise.reject(error)
        }
        
        return promise.future
    }
    
    /**
    Operator. Generates a new Future with the same success type, but a different error type. If the first future succeeds,
    the success value will be passed through to the new future. Ideal for when a more domain-specific error is needed.
     
     Example:
     ```
     let myFuture = Promise<Int, MyIntError>.future
     let myNewFuture = myFuture.mapError { (firstError)
        return MyErrorType(message: "Couldn't get the integer.")
     }
     // Returns a future of type Future<Int, MyErrorType>
     ```
    
    - Parameter mapBlock: The mapping block, which is executed on completion of the future. The block takes a single argument,
      which is of the error type `E` of the original future, and returns a value of the error type `NewError` of the new future.
    - returns: The new future, as a `@discardableResult` to allow for the chaining of mutation/callback methods.
    */
    @discardableResult func mapError<NewError: Error>(_ mapBlock:@escaping (E) -> (NewError)) -> Future<T, NewError> {
        let promise = Promise<T, NewError>()
        
        onFailure { (error) in
            let newError = mapBlock(error)
            promise.reject(newError)
        }
        onSuccess { (value) in
            promise.resolve(value)
        }
        
        return promise.future
    }
    
    /// Allows values to conditionally trigger the error state. Used for when only a constrained range of data values are valid.
    @discardableResult func splitValueMap<NewT>(_ mapping: @escaping (T) -> Result<NewT, E>) -> Future<NewT, E> {
        mapResult { result -> Result<NewT, E> in
            switch result {
            case .success(let value):
                return mapping(value)
            case .failure(let error):
                return .failure(error)
            }
        }
    }
    
    /// Allows errors to conditionally trigger the success/value/data state. Used for when some error states on a future represent success states in a new context.
    @discardableResult func splitErrorMap<NewE>(_ mapping: @escaping (E) -> Result<T, NewE>) -> Future<T, NewE> {
        mapResult { result -> Result<T, NewE> in
            switch result {
            case .success(let value):
                return .success(value)
            case .failure(let error):
                return mapping(error)
            }
        }
    }
    
    /// When T is an optional type, this function generates a new subscriber that only emits
    /// the non-nil states. When the value is nil, this future will never complete, rather
    /// than complete with an error. Failure states will pass through.
    @discardableResult func compactMap<Unwrapped>() -> Future<Unwrapped,E> where T == Unwrapped? {
        let promise = Promise<Unwrapped,E>()
        
        onSuccess { optionalValue in
            if let unwrapped = optionalValue {
                promise.resolve(unwrapped)
            }
        }
        onFailure { error in
            promise.reject(error)
        }
        
        return promise.future
    }
    
    /// A compact map method for when a silent failure is not an acceptable outcome.
    /// When T is an optional type, this function generates a new subscriber that only emits
    /// the non-nil states. When the value is nil, this future will return the `fallbackError`.
    /// Failure states will be passed to the `errorMap` closure.
    @discardableResult func compactMap<NewT, NewE: Error>(
        fallbackError: NewE,
        errorMap: @escaping (E) -> NewE
    ) -> Future<NewT,NewE> where T == NewT? {
        mapError(errorMap)
        .splitValueMap { optionalValue in
            guard let unwrapped = optionalValue else {
                return .failure(fallbackError)
            }
            return .success(unwrapped)
        }
    }
    
}

public extension Future {
    
    /// Operator. Maps the result of this future to the kicking off of another future. Primarily used to serialize async work.
    ///
    /// - Parameter mapBlock: Closure which generates the new future. Takes in the `Result<T,E>` from the completion of the first future.
    /// - returns: The new future, as a `@discardableResult` to allow for the chaining of operators.
    @discardableResult func flatMap<NewT, NewE: Error>(_ mapBlock: @escaping (Result<T,E>) -> Future<NewT,NewE>) -> Future<NewT,NewE> {
        let promise = Promise<NewT,NewE>()
        
        finally {
            mapBlock($0)
                .onSuccess { promise.resolve($0) }
                .onFailure { promise.reject($0) }
        }
        
        return promise.future
    }
    
    /**
    Operator. Maps the success value of this future to the kicking off of another future. Errors are passed through unchanged.
    
    - Parameter mapBlock: Closure which generates the new future. Takes in the `Result<T,E>` from the completion of the first future.
    - returns: The new future, as a `@discardableResult` to allow for the chaining of mutation/callback methods.
    */
    @discardableResult func flatMapSuccess<NewT>(_ mapBlock: @escaping (T) -> Future<NewT,E>) -> Future<NewT,E> {
        let promise = Promise<NewT,E>()
        
        onSuccess {
            mapBlock($0)
                .onSuccess { promise.resolve($0) }
                .onFailure { promise.reject($0) }
        }
        
        onFailure { error in
            promise.reject(error)
        }
        
        return promise.future
    }
    
}
