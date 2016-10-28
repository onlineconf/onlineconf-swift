import XCTest
import CCKV
import Foundation
@testable import OnlineConf

func errcv(path: String, call: String, num : Int) {
	print("Error num \(num), path \(path) and call \(call)" )
}

class OnlineConfTests: XCTestCase {
	func testExample() {
		let cfg = try? Config(path: "test.cdb", ecb: errcv)
		if cfg == nil { print ("CFG is nil") }
		let key = "/my/antispam/ratelimit/mras/complaint/limits"
		let v: Any? = Config.getJSON("/my/api/apps/bonus-actions")
		if v != nil { print ("Value \(v!)") }
		else { print("Not found") }
	}

	func checkMemory() {
		print("\(#file)")
		let file = "String"
		let cfg = try? Config(path: "test.cdb", ecb: errcv)
		if cfg != nil {
			var stream = open("test.cdb", 0, 0)
		}
	}

	static var allTests : [(String, (OnlineConfTests) -> () throws -> Void)] {
		return [
			("testExample", testExample),
			("checkmemory", checkMemory)
		]
	}
}
