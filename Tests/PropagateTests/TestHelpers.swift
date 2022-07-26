//  TestHelpers.swift
//  PropagateTests
//  Created by Jake Hawken on 10/11/17.
//  Copyright © 2017 Jacob Hawken. All rights reserved.

import Propagate
import Foundation
import XCTest

func item<T>(_ item: Any?, isA: T.Type, and evalBlock: (T) -> (Bool)) -> Bool {
    if let unwrapped = item as? T {
        return evalBlock(unwrapped)
    }
    else {
        return false
    }
}

extension Date {
    func isAfter(_ otherDate: Date) -> Bool {
        return timeIntervalSince(otherDate) > 0
    }
    
    func isBefore(_ otherDate: Date) -> Bool {
        return timeIntervalSince(otherDate) < 0
    }
}

enum TestError: Error {
    case case1
}

extension XCTestCase {
    
    @discardableResult func waitForNextState<T,E:Error>(timeout: TimeInterval = 0.01, subscriberBlock: () -> Subscriber<T,E>) -> Subscriber<T,E> {
        let subscriber = subscriberBlock()
        
        let expectation = expectation(description: "\(subscriber) should emit within \(timeout) second\(timeout != 1 ? "s" : "").")
        subscriber.subscribe { _ in
            expectation.fulfill()
        }
        
        waitForExpectations(timeout: timeout)
        
        return subscriber
    }
    
}
