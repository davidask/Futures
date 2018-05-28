#if os(Linux)

@testable import FuturesTests
import XCTest

XCTMain([
    testCase(FuturesTests.allTests)
])

#endif
