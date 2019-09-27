import XCTest
@testable import OnlineConfTests

#if canImport(OnlineConfPerlTests)
	@testable import OnlineConfPerlTests
	XCTMain([
		testCase(OnlineConfTests.allTests),
		testCase(OnlineConfPerlTests.allTests),
	])
#else
	XCTMain([
		testCase(OnlineConfTests.allTests),
	])
#endif
