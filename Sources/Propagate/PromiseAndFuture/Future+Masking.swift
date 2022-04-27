//  Future+Masking.swift
//  Propagate
//  Created by Jacob Hawken on 4/5/22.

import Foundation

public extension Future {
    
    /// Maps to a future that updates with Void on success. For cases where the success value
    /// is not relevant, but the error value is.
    @discardableResult func mapToVoid() -> Future<Void, E> {
        mapValue { _ in () }
    }
    
    /// Uses `mapError(_:)` and employs the automatic bridging to NSError that is included in
    /// Foundation's Objective-C/Swift interoperability.
    @discardableResult func mapToNSError() -> Future<T, NSError> {
        return mapError { $0 as NSError }
    }
    
    /// Convenience method for type erasure of a future.
    @discardableResult func typeErased() -> Future<Any, NSError> {
        return mapValue { (value) -> Any in
            return value
        }
        .mapToNSError()
    }
    
    func successOnly() -> SuccessOnlyFuture<T> {
        SuccessOnlyFuture(future: self)
    }

}

public class SuccessOnlyFuture<T> {
    
    private var onSuccessBlock: (@escaping (T) -> Void) -> Void
    private var valueBlock: () -> T?
    
    public var value: T? {
        valueBlock()
    }
    
    init<E: Error>(future: Future<T, E>) {
        onSuccessBlock = { action in
            future.onSuccess { successVal in
                action(successVal)
            }
        }
        valueBlock = {
            future.value
        }
    }
    
    init<OtherT>(otherFuture: SuccessOnlyFuture<OtherT>, mapping: @escaping (OtherT) -> T) {
        onSuccessBlock = { action in
            otherFuture.onSuccess { otherValue in
                let thisValue = mapping(otherValue)
                action(thisValue)
            }
        }
        valueBlock = {
            guard let otherValue = otherFuture.value else {
                return nil
            }
            return mapping(otherValue)
        }
    }
    
}

public extension SuccessOnlyFuture {
    
    func onSuccess(_ action: @escaping (T) -> Void) {
        onSuccessBlock(action)
    }
    
    func map<NewT>(_ mapping: @escaping (T) -> NewT) -> SuccessOnlyFuture<NewT> {
        return SuccessOnlyFuture<NewT>(otherFuture: self, mapping: mapping)
    }
    
}
