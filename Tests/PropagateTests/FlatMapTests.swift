//  FlatMapTests.swift
//  Created by Jacob Hawken on 8/13/22.

import Propagate
import XCTest

class FlatMapTests: XCTestCase {
    
    private var promise: Promise<Int,TestError>!
    private var future: Future<Int,TestError>!

    override func setUp() {
        promise = .init()
        future = promise.future
    }
    
    override func tearDown() {
        promise = nil
        future = nil
    }
    
    func testFlatMapTriggersSecondFuture() {
        var flatMappedFuture = future.flatMap { result in
            mapIntResultToStringFuture(result)
        }
        promise.resolve(5)
        waitForCompletion(of: flatMappedFuture)
        XCTAssertEqual(flatMappedFuture.value, "5")
        
        promise = .init()
        future = promise.future
        flatMappedFuture = future.flatMap { result in
            mapIntResultToStringFuture(result)
        }
        promise.reject(TestError.case1)
        waitForCompletion(of: flatMappedFuture)
        XCTAssertEqual(flatMappedFuture.error, OtherTestError.case1)
    }
    
    func testFlatMapSuccessTriggersSecondFuture() {
        let flatMappedFuture = future.flatMapSuccess { int in
            triggerFutureForInt(int, shouldSucceed: true)
        }
        promise.resolve(3)
        waitForCompletion(of: flatMappedFuture)
        XCTAssertEqual(flatMappedFuture.value, "3")
    }
    
    func testFlatMapSuccessReturnsErrorOfSecondFuture() {
        let flatMappedFuture = future.flatMapSuccess { int in
            triggerFutureForInt(int, shouldSucceed: false)
        }
        promise.resolve(3)
        waitForCompletion(of: flatMappedFuture)
        XCTAssertEqual(flatMappedFuture.error, TestError.case1)
    }
    
    func testFlatMapSuccessPassesThroughError() {
        let flatMappedFuture = future.flatMapSuccess { int in
            triggerFutureForInt(int, shouldSucceed: true)
        }
        promise.reject(TestError.case2)
        waitForCompletion(of: flatMappedFuture)
        XCTAssertEqual(flatMappedFuture.error, TestError.case2)
    }
    
    func testFlatMapErrorTriggersSecondFuture() {
        let flatMappedFuture = future.flatMapError { error in
            triggerFutureForError(error, shouldSucceed: true)
        }
        promise.reject(.case1)
        waitForCompletion(of: flatMappedFuture)
        XCTAssertEqual(flatMappedFuture.value, 69)
    }
    
    func testFlatMapErrorReturnsErrorOfSecondFuture() {
        let flatMappedFuture = future.flatMapError { error in
            triggerFutureForError(error, shouldSucceed: false)
        }
        promise.reject(TestError.case2)
        waitForCompletion(of: flatMappedFuture)
        XCTAssertEqual(flatMappedFuture.error, OtherTestError.case2)
    }
    
    func testFlatMapErrorPassesThroughSuccess() {
        let flatMappedFuture = future.flatMapError { error in
            triggerFutureForError(error, shouldSucceed: false)
        }
        promise.resolve(17)
        waitForCompletion(of: flatMappedFuture)
        XCTAssertEqual(flatMappedFuture.value, 17)
    }

}

private func mapIntResultToStringFuture(_ result: Result<Int,TestError>) -> Future<String,OtherTestError> {
    switch result {
    case .success(let int):
        return .of("\(int)")
    case .failure(let error):
        switch error {
        case .case1:
            return .error(.case1)
        case .case2:
            return .error(.case2)
        }
    }
}

private func triggerFutureForInt(_ int: Int, shouldSucceed: Bool) -> Future<String,TestError> {
    if shouldSucceed {
        return .of("\(int)")
    }
    return .error(.case1)
}

private func triggerFutureForError(_ error: TestError, shouldSucceed: Bool) -> Future<Int,OtherTestError> {
    if shouldSucceed {
        return .of(69)
    }
    switch error {
    case .case1:
        return .error(.case1)
    case .case2:
        return .error(.case2)
    }
}
