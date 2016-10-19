import XCTest
import CCKV
@testable import OnlineConf
import Foundation

func errcv(path: String, call: String, num : Int32) {
	print("Error num \(num), path \(path) and call \(call)" )
}

class OnlineConfTests: XCTestCase {
	func testExample() {
		let cfg = try! Config(path: "test.cdb", ecb: errcv)
		let key = "/my/antispam/ratelimit/mras/complaint/limits"
		let v: Any? = Config.getJson("/my/api/apps/bonus-actions")
		if v != nil { print ("Value \(v!)") }
		else { print("Not found") }
	}

	static var allTests : [(String, (OnlineConfTests) -> () throws -> Void)] {
		return [
			("testExample", testExample),
		]
	}
}
