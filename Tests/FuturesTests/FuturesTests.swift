import Dispatch
@testable import Futures
import XCTest

class FuturesTests: XCTestCase {

    override func setUp() {
        super.setUp()
    }

    override func tearDown() {
        super.tearDown()
    }

    func testBasicPromise() {

        let expectation = self.expectation(description: "measure")

        promise {
            "Hello World!"
        }.whenResolved { result in
            expectation.fulfill()
            XCTAssert(result.isError == false)
        }

        waitForExpectations(timeout: 3, handler: nil)
    }

    func testAsyncPromise() {

        let expectation = self.expectation(description: #function)

        promise(String.self) { completion in
            completion(.fulfilled("Hello World!"))
        }.whenResolved { result in
            expectation.fulfill()
            XCTAssert(result.isError == false)
        }

        waitForExpectations(timeout: 3, handler: nil)
    }

    func testBasicFulfill() {

        let expectation = self.expectation(description: #function)

        promise {
            1
        }.whenFulfilled { _ in
            expectation.fulfill()
        }

        waitForExpectations(timeout: 3, handler: nil)
    }

    func testBasicObserving() {

        func something(throwError: Bool) throws -> Int {
            if throwError {
                throw NSError(domain: "", code: 0, userInfo: nil)
            } else {
                return 1
            }
        }

        let nonThrowingExpectation = expectation(description: "noThrow")

        let nonThrowingFuture = promise {
            try something(throwError: false)
        }

        nonThrowingFuture.whenRejected { _ in
            XCTFail("Should not be rejected")
            nonThrowingExpectation.fulfill()
        }

        nonThrowingFuture.whenFulfilled { value in
            XCTAssertEqual(value, 1)
            nonThrowingExpectation.fulfill()
        }

        let throwingExpectation = expectation(description: "throw")

        let throwingFuture = promise {
            try something(throwError: true)
        }

        throwingFuture.whenRejected { _ in
            throwingExpectation.fulfill()
        }

        throwingFuture.whenFulfilled { _ in
            XCTFail("Should be rejected")
            throwingExpectation.fulfill()
        }

        waitForExpectations(timeout: 3, handler: nil)
    }

    func testBasicReject() {

        let expectation = self.expectation(description: #function)

        promise {
            throw NSError(domain: "", code: 0, userInfo: nil)
        }.whenRejected { _ in
            expectation.fulfill()
        }

        waitForExpectations(timeout: 3, handler: nil)
    }

    func testBasicThen() {

        let expectation = self.expectation(description: #function)

        func add(value: Double, to otherValue: Double) -> Future<Double> {
            return promise {
                value + otherValue
            }
        }

        promise {
            10
        }.then { value in
            add(value: 10, to: value)
        }.then { value in
            add(value: 5, to: value)
        }.whenResolved { result in
            switch result {
            case .fulfilled(let value):
                XCTAssertEqual(value, 25)
            case .rejected:
                XCTFail("Rejected")
            }

            expectation.fulfill()
        }

        waitForExpectations(timeout: 3, handler: nil)
    }

    func testThenIfRejected() {

        let expectation = self.expectation(description: #function)

        promise {
            999
        }.map { errorCode -> String in
            throw NSError(domain: "", code: errorCode, userInfo: nil)
        }.thenIfRejected { _ in
            return promise {
                return "Recovered"
            }
        }.whenFulfilled { string in
            XCTAssertEqual(string, "Recovered")
            expectation.fulfill()
        }

        waitForExpectations(timeout: 3, handler: nil)
    }

    func testMapIfRejected() {

        let expectation = self.expectation(description: #function)

        promise {
            999
        }.map { errorCode -> String in
            throw NSError(domain: "", code: errorCode, userInfo: nil)
        }.mapIfRejected { _ in
            return "Recovered"
        }.whenFulfilled { string in
            XCTAssertEqual(string, "Recovered")
            expectation.fulfill()
        }

        waitForExpectations(timeout: 3, handler: nil)
    }

    func testBasicAnd() {

        let expectation = self.expectation(description: #function)

        let future1 = promise {
            "Hello"
        }

        let future2 = promise {
            "World!"
        }

        future1.and(future2).whenFulfilled { result in

            let (hello, world) = result

            XCTAssertEqual(hello, "Hello")
            XCTAssertEqual(world, "World!")

            expectation.fulfill()
        }

        waitForExpectations(timeout: 3, handler: nil)
    }

    func testReduce() {

        let expectation = self.expectation(description: #function)

        let range = 1 ... 10

        let expected = range.reduce(0) { combined, next in
            combined + next
        }

        let futures = (1 ... 10).map { value in
            promise { value }
        }

        Future<Int>.reduce(futures, initialResult: 0) { combined, next in
            combined + next
        }.whenFulfilled { value in
            XCTAssertEqual(value, expected)
            expectation.fulfill()
        }

        waitForExpectations(timeout: 3, handler: nil)
    }

    func testPerform() {
        let expectation = self.expectation(description: #function)

        var flag = false

        promise {
            true
        }.perform(on: .main) { value, completion in
            XCTAssertEqual(value, true)

            #if !os(Linux)
            XCTAssertEqual(Thread.current, Thread.main)
            #endif

            DispatchQueue.global().async {
                flag = true
                completion()
            }

        }.whenFulfilled { _ in
            XCTAssertEqual(flag, true)
            expectation.fulfill()
        }

        waitForExpectations(timeout: 3, handler: nil)
    }

    func testBasicMap() {
        let expectation = self.expectation(description: #function)

        promise {
            ["Hello", "World!"]
        }.map { strings in
            strings.joined(separator: " ")
        }.whenFulfilled { string in
            XCTAssertEqual(string, "Hello World!")
            expectation.fulfill()
        }

        waitForExpectations(timeout: 3, handler: nil)
    }

    func testBasicPerformance() {

        measure {
            let futures = (0 ... 10_000).map { int in
                return promise {
                    return int
                }
            }

            let expectation = self.expectation(description: "measure")

            Future<Int>.reduce(futures, initialResult: 0) { initial, next in
                return initial + next
            }.whenResolved { result in
                expectation.fulfill()
                XCTAssertNoThrow(result.isError == false)
            }

            waitForExpectations(timeout: 5) { _ in
                self.stopMeasuring()
            }
        }
    }

    static let allTests = [
        ("testBasicPromise", testBasicPromise),
        ("testAsyncPromise", testAsyncPromise),
        ("testBasicFulfill", testBasicFulfill),
        ("testBasicObserving", testBasicObserving),
        ("testBasicReject", testBasicReject),
        ("testBasicThen", testBasicThen),
        ("testThenIfRejected", testThenIfRejected),
        ("testMapIfRejected", testMapIfRejected),
        ("testBasicAnd", testBasicAnd),
        ("testPerform", testPerform),
        ("testBasicMap", testBasicMap),
        ("testBasicPerformance", testBasicPerformance)
    ]
}
