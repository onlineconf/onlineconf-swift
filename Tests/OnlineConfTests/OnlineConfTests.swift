import XCTest
import Foundation
@testable import OnlineConf

class OnlineConfTests: XCTestCase {
	override func setUp() {
		Config.dir = "Tests/OnlineConfTests/"
	}

	func testModule() {
		var cdbstat = stat()
		stat("Tests/OnlineConfTests/TREE.cdb", &cdbstat)
		let config = try! Config.getModule("TREE")
		XCTAssertEqual(config.mtime, cdbstat.st_mtime)
		XCTAssertEqual(config.get("/blogs/closed") ?? 0, 1)
		XCTAssertEqual(config.get("/infrastructure/database/box/UserStatsBox/0ME") ?? "", "alei6.mail.ru:13013")
		XCTAssertEqual(config.get("/infrastructure/database/box/ju/data/available-for-registration") ?? [], ["1","2","3","4","5","7","8","9"])
		let json = config.getJSON("/agent/friendship/check/macagent") as! [String:Int]
		XCTAssertEqual(json, ["check": 1, "and": 1])
		XCTAssertNil(config.get("/negative/key") as String?)
		XCTAssertEqual(config.get("/blogs/closed") ?? [], ["1"])
		XCTAssertTrue(config.get("/blogs/closed") ?? false)
		XCTAssertEqual(config.get("/blogs/closed") ?? 0.0, 1.0)
	}

	func testTree() {
		var cdbstat = stat()
		stat("Tests/OnlineConfTests/TREE.cdb", &cdbstat)
		XCTAssertEqual(Config.mtime, cdbstat.st_mtime)
		XCTAssertEqual(Config.get("/blogs/closed") ?? 0, 1)
		XCTAssertEqual(Config.get("/infrastructure/database/box/UserStatsBox/0ME") ?? "", "alei6.mail.ru:13013")
		XCTAssertEqual(Config.get("/infrastructure/database/box/ju/data/available-for-registration") ?? [], ["1","2","3","4","5","7","8","9"])
		let json = Config.getJSON("/agent/friendship/check/macagent") as? [String:Int]
		XCTAssertEqual(json, ["check": 1, "and": 1])
		XCTAssertNil(Config.get("/negative/key") as String?)
		XCTAssertEqual(Config.get("/blogs/closed") ?? [], ["1"])
		XCTAssertTrue(Config.get("/blogs/closed") ?? false)
		XCTAssertEqual(Config.get("/blogs/closed") ?? 0.0, 1.0)
	}

	func testIterator() {
		let config = try! Config.getModule("TREE")
		let dict = [String: Any](uniqueKeysWithValues: config)
		XCTAssertEqual(dict["/blogs/closed"] as? String, "1")
		XCTAssertEqual(dict["/agent/friendship/check/macagent"] as? [String: Int], ["check": 1, "and": 1])
	}

	func testMeta() {
		var st = stat()
		stat("Tests/OnlineConfTests/TREE.cdb", &st)
		XCTAssertEqual(st.st_mtime, Config.mtime)
		let config = try! Config("TREE")
		XCTAssertEqual(st.st_mtime, config.mtime)
		let recheck = config.recheckTime
		Thread.sleep(forTimeInterval: 1)
		XCTAssertFalse(config.reload())
		XCTAssertEqual(config.recheckTime, recheck)
		try! config.forceReload()
		XCTAssertNotEqual(config.recheckTime, recheck)
		XCTAssertEqual(st.st_mtime, config.mtime)
		XCTAssertEqual(1, config.get("/blogs/closed") ?? 0)
	}

	static var allTests : [(String, (OnlineConfTests) -> () throws -> Void)] {
		return [
			("testModule", testModule),
			("testTree", testTree),
			("testIterator", testIterator),
			("testMeta", testMeta),
		]
	}
}
