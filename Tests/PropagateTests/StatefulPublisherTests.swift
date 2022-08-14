//  StatefulPublishertests.swift
//  PropagateTests
//  Created by Jacob Hawken on 7/24/22.

import Propagate
import XCTest

class StatefulPublishertests: XCTestCase {
    
    private var sourcePublisher: Publisher<Int,TestError>!
    private var sourceSubscriber: Subscriber<Int,TestError>!
    private var subject: Subscriber<Int,TestError>!

    override func setUpWithError() throws {
        sourcePublisher = .init()
        sourceSubscriber = sourcePublisher.subscriber()
        subject = sourceSubscriber.stateful()
    }

    override func tearDownWithError() throws {
        sourcePublisher = nil
        sourceSubscriber = nil
        subject = nil
    }
    
    func testEmitLastStateOnSubscription() {
        var receivedValue: Int?
        
        sourcePublisher.publish(5)
        
        waitForNextState(
            forSubscriber: subject.onNewData { receivedValue = $0 }
        )
        
        XCTAssertNotNil(receivedValue)
        XCTAssertEqual(receivedValue, 5)
    }

}
