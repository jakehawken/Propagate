//  SubscriberCombineTests.swift
//  PropagateTests
//  Created by Jacob Hawken on 5/6/22.

import Propagate
import XCTest

class SubscriberCombineTests: XCTestCase {
    
    private var publisher1: Publisher<Int,TestError>!
    private var subscriber1: Subscriber<Int,TestError>!
    
    private var publisher2: Publisher<String,TestError>!
    private var subscriber2: Subscriber<String,TestError>!

    override func setUp() {
        publisher1 = .init()
        subscriber1 = publisher1.subscriber()
        
        publisher2 = .init()
        subscriber2 = publisher2.subscriber()
    }

    override func tearDown() {
        publisher1 = nil
        subscriber1 = nil
        publisher2 = nil
        subscriber2 = nil
    }
    
    func testCombineTwoSubscribers() {
        var lastStateReceived: Subscriber<(Int, String), TestError>.State?
        let combinedSub = Subscriber.combine(subscriber1, subscriber2).subscribe {
            lastStateReceived = $0
        }
        
        publisher2.publish("A")
        confirmNextStateDoesntTrigger(forSubscriber: combinedSub)
        XCTAssertNil(lastStateReceived)
        
        publisher1.publish(1)
        waitForNextState(forSubscriber: combinedSub)
        XCTAssertNotNil(lastStateReceived)
        XCTAssertNotNil(lastStateReceived?.value)
        XCTAssertEqual(lastStateReceived?.value?.0, 1)
        XCTAssertEqual(lastStateReceived?.value?.1, "A")
        
        publisher1.publish(2)
        waitForNextState(forSubscriber: combinedSub)
        XCTAssertNotNil(lastStateReceived?.value)
        XCTAssertEqual(lastStateReceived?.value?.0, 2)
        XCTAssertEqual(lastStateReceived?.value?.1, "A")
        
        publisher2.publish(.case2)
        waitForNextState(forSubscriber: combinedSub)
        XCTAssertNotNil(lastStateReceived?.error)
        XCTAssertEqual(lastStateReceived?.error, .case2)
        
        publisher2.publish("B")
        waitForNextState(forSubscriber: combinedSub)
        XCTAssertNotNil(lastStateReceived?.value)
        XCTAssertEqual(lastStateReceived?.value?.0, 2)
        XCTAssertEqual(lastStateReceived?.value?.1, "B")
        
        publisher1.publish(.case1)
        waitForNextState(forSubscriber: combinedSub)
        XCTAssertNotNil(lastStateReceived?.error)
        XCTAssertEqual(lastStateReceived?.error, .case1)
        
        publisher1.publish(3)
        waitForNextState(forSubscriber: combinedSub)
        XCTAssertNotNil(lastStateReceived?.value)
        XCTAssertEqual(lastStateReceived?.value?.0, 3)
        XCTAssertEqual(lastStateReceived?.value?.1, "B")
    }

}
