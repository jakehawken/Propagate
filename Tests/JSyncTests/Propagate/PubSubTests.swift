//  PubSubTests.swift
//  PropagateTests
//  Created by Jake Hawken on 4/5/20.
//  Copyright © 2020 Jake Hawken. All rights reserved.

import XCTest
import JSync

class PubSubTests: XCTestCase {
    
    var publisher: Publisher<Int, TestError>!
    var subscriber1: Subscriber<Int, TestError>!
    var subscriber2: Subscriber<Int, TestError>!
    var subscriber3: Subscriber<Int, TestError>!

    override func setUp() {
        publisher = Publisher()
    }

    override func tearDown() {
        subscriber1 = nil
        subscriber2 = nil
        subscriber3 = nil
        publisher = nil
    }

    func testPublisherGeneratesCorrectlyConnectedSubscriber() {
        let expectation1 = expectation(description: "All values published.")
        var subscriptionValues = [Int]()
        let valuesToEmit = [4, 2, 7, 1, 8]
        
        subscriber1 = publisher.subscriber()
            .onNewData(onQueue: .main) { value in
                subscriptionValues.append(value)
                if valuesToEmit.last == value {
                    expectation1.fulfill()
                }
            }
        
        valuesToEmit.forEach {
            publisher.publish($0)
        }
        
        waitForExpectations(timeout: 0.01, handler: nil)
        XCTAssertEqual(subscriptionValues, valuesToEmit)
        
        var errors = [TestError]()
        
        let expectation2 = expectation(description: "Error received.")
        subscriber1.onError { error in
            errors.append(error)
            if TestError.allCases.last == error {
                expectation2.fulfill()
            }
        }
        
        TestError.allCases.forEach {
            publisher.publish($0)
        }
        
        waitForExpectations(timeout: 0.01, handler: nil)
        XCTAssertEqual(errors, TestError.allCases)
        
        let cancelExpectation = expectation(description: "Should receive cancel signal.")
        subscriber1.onCancelled {
            cancelExpectation.fulfill()
        }
        
        publisher.cancelAll()
        publisher.publish(249)
        publisher.publish(.case1)
        waitForExpectations(timeout: 0.01, handler: nil)
        // Verify that no attempted emissions succeed after cancellation
        XCTAssertEqual(subscriptionValues, valuesToEmit)
        XCTAssertEqual(errors, TestError.allCases)
    }
    
    func testMultipleSubscribersGetUpdates() {
        let emittedStates: [StreamState<Int, TestError>] = [
            .data(0), .error(.case1), .data(2), .error(.case2),
            .data(4), .error(.case3), .cancelled
        ]
        
        let expectations = (1...3).map {
            expectation(description: "Last state received on subscriber\($0).")
        }
        
        var subscriber1ReceivedStates = [StreamState<Int, TestError>]()
        subscriber1 = publisher.subscriber().subscribe {
            subscriber1ReceivedStates.append($0)
        }
        .onCancelled {
            expectations[0].fulfill()
        }
        
        var subscriber2ReceivedStates = [StreamState<Int, TestError>]()
        subscriber2 = publisher.subscriber().subscribe {
            subscriber2ReceivedStates.append($0)
        }
        .onCancelled {
            expectations[1].fulfill()
        }
        
        var subscriber3ReceivedStates = [StreamState<Int, TestError>]()
        subscriber3 = publisher.subscriber().subscribe {
            subscriber3ReceivedStates.append($0)
        }
        .onCancelled {
            expectations[2].fulfill()
        }
        
        emittedStates.forEach { state in
            switch state {
            case let .data(data):
                publisher.publish(data)
            case let .error(error):
                publisher.publish(error)
            case .cancelled:
                publisher.cancelAll()
            }
        }
        
        wait(for: expectations, timeout: 0.1)
        XCTAssertEqual(subscriber1ReceivedStates, emittedStates)
        XCTAssertEqual(subscriber2ReceivedStates, emittedStates)
        XCTAssertEqual(subscriber3ReceivedStates, emittedStates)
    }
    
    func testPublishserBeingReleasedFromMemoryTriggersCancellation() {
        let expectations = (1...3).map { expectation(description: "Should cancel for subscriber\($0).") }
        subscriber1 = publisher.subscriber().onCancelled {
            expectations[0].fulfill()
        }
        subscriber2 = publisher.subscriber().onCancelled {
            expectations[1].fulfill()
        }
        subscriber3 = publisher.subscriber().onCancelled {
            expectations[2].fulfill()
        }
        DispatchQueue.global().async {
            DispatchQueue.main.sync {
                self.publisher = nil
            }
        }
        
        wait(for: expectations, timeout: 0.1)
    }

}

enum TestError: String, Error, Equatable, CaseIterable, CustomStringConvertible {
    case case1
    case case2
    case case3
    
    var description: String {
        return ".\(rawValue)"
    }
}
