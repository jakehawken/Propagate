//  MapTests.swift
//  PropagateTests
//  Created by Jacob Hawken on 3/8/22.
//  Copyright © 2022 Jake Hawken. All rights reserved.

import XCTest
import JSync

class MapTests: XCTestCase {
    
    var publisher: Publisher<Int, TestError>!
    var subscriber1: Subscriber<String, TestError>!
    var subscriber2: Subscriber<Int, TestError2>!
    var subscriber3: Subscriber<String, TestError2>!
    
    override func setUp() {
        publisher = Publisher()
    }

    override func tearDown() {
        subscriber1 = nil
        subscriber2 = nil
        subscriber3 = nil
        publisher = nil
    }
    
    func testMappedStatesPassThroughToSubscribers() {
        let inputs: [StreamState<Int, TestError>] = [
            .data(0), .data(7), .error(.case2),
            .data(4), .data(1), .error(.case1),
            .data(-14), .error(.case3), .cancelled, .data(69)
        ]
        
        let subscriber4Expectation = expectation(description: "Subsciber 4 finished.")
        var subscriber4Outputs = [StreamState<String, TestError>]()
        subscriber1 = publisher
            .subscriber()
            .mapValues { "\($0)" }
            .subscribeOnMain {
                subscriber4Outputs.append($0)
            }
            .onCancelled(onQueue: .main) {
                subscriber4Expectation.fulfill()
            }
        let subscriber4ExpectedOutputs: [StreamState<String, TestError>] = [
            .data("0"), .data("7"), .error(.case2),
            .data("4"), .data("1"), .error(.case1),
            .data("-14"), .error(.case3), .cancelled
        ]
        
        let subscriber5Expectation = expectation(description: "Subsciber 5 finished.")
        var subscriber5Outputs = [StreamState<Int, TestError2>]()
        subscriber2 = publisher
            .subscriber()
            .mapErrors(mapToTestError2(fromTestError:))
            .subscribeOnMain {
                subscriber5Outputs.append($0)
            }
            .onCancelled(onQueue: .main) {
                subscriber5Expectation.fulfill()
            }
        let subscriber5ExpectedOutputs: [StreamState<Int, TestError2>] = [
            .data(0), .data(7), .error(.caseB),
            .data(4), .data(1), .error(.caseA),
            .data(-14), .error(.caseC), .cancelled
        ]
        
        let subscriber6Expectation = expectation(description: "Subsciber 6 finished.")
        var subscriber6Outputs = [StreamState<String, TestError2>]()
        subscriber3 = publisher.subscriber()
            .mapState {
                switch $0 {
                case .data(let data):
                    return .data("\(data)")
                case .error(let error):
                    let mapped = mapToTestError2(fromTestError: error)
                    return .error(mapped)
                case.cancelled:
                    return .cancelled
                }
            }
            .subscribeOnMain {
                subscriber6Outputs.append($0)
            }
            .onCancelled(onQueue: .main) {
                subscriber6Expectation.fulfill()
            }
        let subscriber6ExpectedOutputs: [StreamState<String, TestError2>] = [
            .data("0"), .data("7"), .error(.caseB),
            .data("4"), .data("1"), .error(.caseA),
            .data("-14"), .error(.caseC), .cancelled
        ]
        
        inputs.forEach { state in
            switch state {
            case let .data(data):
                publisher.publish(data)
            case let .error(error):
                publisher.publish(error)
            case .cancelled:
                publisher.cancelAll()
            }
        }
        
        waitForExpectations(timeout: 1, handler: nil)
        XCTAssertEqual(subscriber4Outputs, subscriber4ExpectedOutputs)
        XCTAssertEqual(subscriber5Outputs, subscriber5ExpectedOutputs)
        XCTAssertEqual(subscriber6Outputs, subscriber6ExpectedOutputs)
    }

}

enum TestError2: String, Error, Equatable, CaseIterable, CustomStringConvertible {
    case caseA
    case caseB
    case caseC
    
    var description: String {
        return ".\(rawValue)"
    }
}

func mapToTestError2(fromTestError testError: TestError) -> TestError2 {
    switch testError {
    case .case1:
        return .caseA
    case .case2:
        return .caseB
    case .case3:
        return .caseC
    }
}
