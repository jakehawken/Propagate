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

enum TestError: Error, Equatable {
    case case1
    case case2
}

enum OtherTestError: Error, Equatable {
    case case1
    case case2
}

extension XCTestCase {
    
    func waitForNextState<T,E:Error>(
        forSubscriber subscriber: Subscriber<T,E>,
        timeout: TimeInterval = 0.01
    ) {
        var fulfilled = false
        let expectation = expectation(description: "\(subscriber) should emit within \(timeout) second\(timeout != 1 ? "s" : "").")
        subscriber.subscribe { _ in
            guard fulfilled == false else {
                return
            }
            expectation.fulfill()
            fulfilled = true
        }
        
        waitForExpectations(timeout: timeout)
    }
    
    func confirmNextStateDoesntTrigger<T,E:Error>(
        forSubscriber sub: Subscriber<T,E>,
        timeout: TimeInterval = 0.01
    ) {
        let start = Date()
        let errorMessage = "Subscriber should not emit within \(timeout) seconds."
        let expectation = expectation(description: errorMessage)
        let timer = Timer.scheduledTimer(withTimeInterval: timeout - 0.00001, repeats: false) { timer in
            expectation.fulfill()
            timer.invalidate()
        }
        
        sub.subscribe { _ in
            if timer.isValid {
                XCTFail(
                    "\(errorMessage) Emitted after \(Date().timeIntervalSince(start)) seconds."
                )
            }
        }
        
        waitForExpectations(timeout: timeout)
    }
    
    func waitForCompletion<T,E:Error>(of future: Future<T,E>, timeout: TimeInterval = 0.01) {
        let expectation = expectation(description: "\(future) should complete within \(timeout) second\(timeout != 1 ? "s" : "").")
        future.finally { _ in
            expectation.fulfill()
        }
        waitForExpectations(timeout: timeout)
    }
    
}
