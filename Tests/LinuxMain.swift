#if os(Linux)

import XCTest
@testable import FuturesTests

XCTMain([
    testCase(FuturesTests.allTests),
])

#endif
