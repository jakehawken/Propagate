//  SubscriberCombineTests.swift
//  PropagateTests
//  Created by Jacob Hawken on 5/6/22.

import Propagate
import XCTest

class SubscriberCombineTests: XCTestCase {
    
    private var publisher: Publisher<Int,TestError>!
    private var subscriber: Subscriber<Int,TestError>!

    override func setUpWithError() throws {
        publisher = .init()
        subscriber = publisher.subscriber()
    }

    override func tearDownWithError() throws {
    }

}
