import Foundation
import Propagate
import Nimble
import Quick
import XCTest

class PromiseTests: QuickSpec {
    
  override func spec() {

    var subject: Promise<Int,NSError>!
    let noBuenoError = NSError(domain: "No bueno", code: 666, userInfo: nil)

    describe("Promise") {

        beforeEach {
            subject = Promise<Int,NSError>()
        }
        
        it("should contain an unresolved future") {
            expect(subject.future.isComplete).to(beFalse())
            expect(subject.future.succeeded).to(beFalse())
            expect(subject.future.failed).to(beFalse())
        }
        
        describe("completing the promise") {
            context("when resolving the promise") {
                beforeEach {
                    subject.resolve(3)
                }
                
                it("should resolve the internal promise") {
                    expect(subject.future.isComplete).to(beTrue())
                    expect(subject.future.succeeded).to(beTrue())
                    expect(subject.future.failed).to(beFalse())
                }
            }
            
            context("when rejecting the promise") {
                beforeEach {
                    subject.reject(noBuenoError)
                }
                
                it("should reject the internal promise") {
                    expect(subject.future.isComplete).to(beTrue())
                    expect(subject.future.succeeded).to(beFalse())
                    expect(subject.future.failed).to(beTrue())
                }
            }
        }
        
        describe("using onSuccess, onFailure, and finally blocks") {
            var successValue: Int?
            var errorValue: NSError?
            var primaryTimestamp: Date?
            var finallyHappened: Bool = false
            
            beforeEach {
                successValue = nil
                errorValue = nil
                finallyHappened = false
                
                subject = Promise<Int,NSError>()
                
                subject.future.onSuccess { (value) in
                    primaryTimestamp = Date()
                    successValue = value
                }.onFailure { (error) in
                  errorValue = error as NSError
                }.finally { (_) in
                    finallyHappened = true
                }
            }
            
            context("when the promise is rejected") {
                beforeEach {
                    subject.reject(noBuenoError)
                }
                
                it("should hit the error block, and not the success block") {
                    expect(errorValue).toNotEventually(beNil())
                    expect(errorValue).to(equal(noBuenoError))
                    expect(successValue).to(beNil())
                }
                
                it("should call the finally block no matter what") {
                    expect(finallyHappened).toEventually(beTrue())
                }
            }
            
            context("when the promise is resolved") {
                beforeEach {
                    subject.resolve(3)
                }
                
                it("should hit the error block, and not the success block") {
                    expect(errorValue).to(beNil())
                    expect(successValue).toNotEventually(beNil())
                    expect(successValue).to(equal(3))
                }
                
                it("should call the finally block no matter what") {
                    expect(finallyHappened).toEventually(beTrue())
                }
            }
            
            context("when there are multiple then blocks") {
                var secondarySuccessValue: String?
                var secondaryTimeStamp: Date?
                var tertiarySuccessValue: Float?
                var tertiaryTimeStamp: Date?
                
                beforeEach {
                    subject.future.onSuccess { (value) in
                        secondaryTimeStamp = Date()
                        secondarySuccessValue = "\(value)"
                    }
                    
                    subject.future.onSuccess { (value) in
                        tertiaryTimeStamp = Date()
                        tertiarySuccessValue = Float(value)
                    }
                    
                    subject.resolve(5)
                }
                
                it("should execute the then blocks in order") {
                    expect(successValue).toEventually(equal(5))
                    expect(secondarySuccessValue).toEventually(equal("5"))
                    expect(secondaryTimeStamp?.isAfter(primaryTimestamp!)).toEventually(beTrue())
                    expect(tertiarySuccessValue).toEventually(equal(5))
                    guard let tertiary = tertiaryTimeStamp, let secondary = secondaryTimeStamp else {
                        XCTFail("Both timestamps should be populated.")
                        return
                    }
                    expect(tertiary.isAfter(secondary)).toEventually(beTrue())
                }
                
            }

        }
        
        describe("using preResolved(_) and preRejected(_)") {
            var future: Future<Int,NSError>?

            context("when using preResolved") {
                beforeEach {
                    future = Future.of(7)
                }

                it("should return a synchronously rejected future") {
                    expect(future?.isComplete).to(beTrue())
                    expect(future?.failed).to(beFalse())
                    expect(future?.succeeded).to(beTrue())
                    expect(future?.value).to(equal(7))
                    expect(future?.error).to(beNil())
                }
            }

            context("when using preRejected") {
                beforeEach {
                    future = Future.error(noBuenoError)
                }

                it("should return a synchronously rejected future") {
                    expect(future?.isComplete).to(beTrue())
                    expect(future?.failed).to(beTrue())
                    expect(future?.succeeded).to(beFalse())
                    expect(future?.value).to(beNil())
                    expect(future?.error).toNot(beNil())
                }
            }
        }
        
        describe("mapping result") {
            var returnedFuture: Future<String,NSError>!
            
            beforeEach {
                returnedFuture = subject.future.mapResult { (result) -> (Result<String,NSError>) in
                    switch result {
                    case .success(let intVal):
                        return .success("\(intVal)")
                    case .failure(let nsError):
                        return .failure(nsError)
                    }
                }
            }
            
            context("when the first future fails") {
                var couldntGetIntError: NSError!
                
                beforeEach {
                    couldntGetIntError = NSError(domain: "No int.", code: 0, userInfo: nil)
                    subject.reject(couldntGetIntError)
                }
                
                it("should reject the second future") {
                    expect(returnedFuture.failed).toEventually(beTrue())
                    expect(returnedFuture.error).toEventually(equal(couldntGetIntError))
                }
            }
            
            context("when the first future succeeds") {
                beforeEach {
                    subject.resolve(3)
                }
                
                it("should resolve the returned future") {
                    expect(returnedFuture.succeeded).toEventually(beTrue())
                    expect(returnedFuture.error).toEventually(beNil())
                    expect(returnedFuture.value).toEventually(equal("3"))
                }
            }
        }
        
        describe("mapping value") {
            var returnedFuture: Future<String,NSError>!
            
            beforeEach {
                returnedFuture = subject.future.mapValue { "\($0)" }
            }
            
            context("when the first future fails") {
                var couldntGetIntError: NSError!
                
                beforeEach {
                    couldntGetIntError = NSError(domain: "No int.", code: 0, userInfo: nil)
                    subject.reject(couldntGetIntError)
                }
                
                it("should reject the second future") {
                    expect(returnedFuture.failed).toEventually(beTrue())
                    expect(returnedFuture.error).toEventually(equal(couldntGetIntError))
                }
            }
            
            context("when the first future succeeds") {
                beforeEach {
                    subject.resolve(3)
                }
                
                it("should resolve the returned future with the mapped success") {
                    expect(returnedFuture.succeeded).toEventually(beTrue())
                    expect(returnedFuture.error).toEventually(beNil())
                    expect(returnedFuture.value).toEventually(equal("3"))
                }
            }
        }
        
        describe("mapping error") {
            var returnedFuture: Future<Int,BasicTestingError>!
            
            beforeEach {
                returnedFuture = subject.future.mapError { (_) -> BasicTestingError in
                    return BasicTestingError(message: "Yuh-oh!")
                }
            }
            
            context("when the first future fails") {
                let couldntGetIntError = BasicTestingError(message: "Yuh-oh!")
                
                beforeEach {
                    subject.reject(couldntGetIntError as NSError)
                }
                
                it("should reject the second future with the mapped error") {
                    expect(returnedFuture.failed).toEventually(beTrue())
                    guard let returnedError = returnedFuture.error else {
                        XCTFail("Error should not be nil.")
                        return
                    }
                    expect(returnedError).toEventually(equal(couldntGetIntError))
                    expect(returnedError.message).toEventually(equal("Yuh-oh!"))
                }
            }
            
            context("when the first future succeeds") {
                beforeEach {
                    subject.resolve(3)
                }
                
                it("should resolve the returned future") {
                    expect(returnedFuture.succeeded).toEventually(beTrue())
                    expect(returnedFuture.error).toEventually(beNil())
                    expect(returnedFuture.value).toEventually(equal(3))
                }
            }
        }
        
        describe("merging") {
            var future: Future<[Int],NSError>!
            let genericError = NSError(domain: "Oops!", code: 0, userInfo: nil)
            let specificError = NSError(domain: "Uh-oh!", code: 1, userInfo: nil)
            var successValues: [Int]?
            var errorFromFuture: NSError?
            
            beforeEach {
                successValues = nil
                errorFromFuture = nil
            }
            
            context("when all of the values succeed") {
                beforeEach {
                    let intFutures: [Future<Int,NSError>] = [
                        Future.of(5),
                        Future.of(3),
                        Future.of(7)
                    ]
                    future = Future.merge(intFutures)
                        .onSuccess { (values) in
                            successValues = values
                        }
                        .onFailure { (error) in
                            errorFromFuture = error
                        }
                }
                
                it("should resolve the future with an array of the success values") {
                    expect(successValues).toEventually(contain([5, 3, 7]))
                    expect(future.succeeded).toEventually(beTrue())
                }
            }
            
            context("when all of the values fail") {
                beforeEach {
                    let intFutures: [Future<Int,NSError>] = [
                        Future.error(specificError),
                        Future.error(genericError),
                        Future.error(genericError)
                    ]
                    future = Future.merge(intFutures)
                        .onSuccess { (values) in
                            successValues = values
                        }
                        .onFailure { (error) in
                            errorFromFuture = error
                        }
                }
                
                it("should reject the future with the first error encountered") {
                    expect(successValues).toEventually(beNil())
                    expect(future.failed).toEventually(beTrue())
                    expect(errorFromFuture).toEventually(equal(specificError))
                }
            }
            
            context("when one or more of the values fail") {
                beforeEach {
                    let intFutures: [Future<Int,NSError>] = [
                        Future.of(5),
                        Future.error(genericError),
                        Future.of(7)
                    ]
                    
                    future = Future.merge(intFutures)
                        .onSuccess { (values) in
                            successValues = values
                        }
                        .onFailure { (error) in
                            errorFromFuture = error
                        }
                }
                
                it("should reject the future with the first error encountered") {
                    expect(successValues).to(beNil())
                    expect(future.failed).toEventually(beTrue())
                    expect(errorFromFuture).toEventuallyNot(beNil())
                    expect(errorFromFuture).toEventually(equal(genericError))
                }
            }
        }
        
        describe("firstFinished(from:)") {
            var promise1: Promise<Int,NSError>!
            var promise2: Promise<Int,NSError>!
            var promise3: Promise<Int,NSError>!
            var futures: [Future<Int,NSError>]!
            var joinedFuture: Future<Int,NSError>!
            
            beforeEach {
                promise1 = Promise<Int,NSError>()
                promise2 = Promise<Int,NSError>()
                promise3 = Promise<Int,NSError>()
                futures = [promise1.future, promise2.future, promise3.future]
                joinedFuture = Future.firstFinished(from: futures)
            }
            
            context("when the first finishes first") {
                beforeEach {
                    promise1.resolve(1)
                    promise2.resolve(2)
                    promise3.resolve(3)
                }
                
                it("should resolve the joined future with the first value") {
                    expect(joinedFuture.isComplete).toEventually(beTrue())
                    expect(joinedFuture.succeeded).toEventually(beTrue())
                    expect(joinedFuture.value).toEventually(equal(1))
                }
            }
            
            context("when the second finishes first") {
                beforeEach {
                    promise2.resolve(2)
                    promise1.resolve(1)
                    promise3.resolve(3)
                }
                
                it("should resolve the joined future with the second value") {
                    expect(joinedFuture.isComplete).toEventually(beTrue())
                    expect(joinedFuture.succeeded).toEventually(beTrue())
                    expect(joinedFuture.value).toEventually(equal(2))
                }
            }
            
            context("when the third finishes first") {
                beforeEach {
                    promise3.resolve(3)
                    promise1.resolve(1)
                    promise2.resolve(2)
                }
                
                it("should resolve the joined future with the third value") {
                    expect(joinedFuture.isComplete).toEventually(beTrue())
                    expect(joinedFuture.succeeded).toEventually(beTrue())
                    expect(joinedFuture.value).toEventually(equal(3))
                }
            }
        }

    }

  }

}

struct BasicTestingError: Error, Equatable {
    let message: String
}
