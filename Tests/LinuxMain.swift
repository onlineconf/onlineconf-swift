import XCTest
@testable import OnlineConfTests
@testable import OnlineConfPerlTests

XCTMain([
	testCase(OnlineConfTests.allTests),
	testCase(OnlineConfPerlTests.allTests),
])
