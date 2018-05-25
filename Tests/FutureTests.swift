import XCTest
@testable import Future

class FutureTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testPerformance() {

        measureMetrics([.wallClockTime], automaticallyStartMeasuring: true) {

            let queue = DispatchQueue(label: "measure")

            let futures = (0 ... 10_000).map { int in
                return promise(on: queue) {
                    return int
                }
            }

            let expectation = self.expectation(description: "measure")

            Future<Int>.reduce(futures, on: queue, initialResult: 0) { initial, next in
                return initial + next
            }.whenResolved(on: queue) { result in
                expectation.fulfill()
                XCTAssertNoThrow(result.isError == false)
            }

            waitForExpectations(timeout: 5) { _ in
                self.stopMeasuring()
            }
        }
    }
    
    func testPerformanceExample() {
        // This is an example of a performance test case.
        self.measure {
            // Put the code you want to measure the time of here.
        }
    }
    
}
