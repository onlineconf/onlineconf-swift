import XCTest
import Foundation
@testable import OnlineConf

func errcv(path: String, call: String, num : Int) {
	print("Error code: \(num)", "Path: \(path)", "Call: \(call)", separator: "\n", to: &errStream)
}

class OnlineConfTests: XCTestCase {
	func testLocalConf() {
		let olddir = Config.dir
		Config.dir = "Tests/OnlineConfTests/"
		defer { Config.dir = olddir }
		var cdbstat = stat()
		stat("Tests/OnlineConfTests/test.cdb", &cdbstat)
		let config = try! Config("test", onError: errcv)
		XCTAssertEqual(1, config.get("/blogs/closed")! as Int)
		XCTAssertEqual("alei6.mail.ru:13013", config.get("/infrastructure/database/box/UserStatsBox/0ME")! as String)
		XCTAssertEqual(["1","2","3","4","5","7","8","9"], config.get("/infrastructure/database/box/ju/data/available-for-registration")! as [String])
		let json = config.getJSON("/agent/friendship/check/macagent") as! [String:Int]
		XCTAssertEqual(json["check"]!, 1)
		XCTAssertEqual(json["and"]!, 1)
		XCTAssertFalse(config.get("/negative/key"))
		XCTAssertEqual(config.mtime, cdbstat.st_mtim.tv_sec)
		let strs: [String] = config.get("/blogs/closed")!
		XCTAssertEqual("1", strs[0])
		XCTAssertEqual(1, strs.count)
		XCTAssertTrue(config.get("/blogs/closed"))
		XCTAssertEqual(config.get("/blogs/closed")! as Double, 1.0)
	}

	func testTreeConf() {
		if let str: String = Config.get("/clicker/url/mm/url_expire") {
			XCTAssertEqual(str, "http://my.titan.netbridge.ru/cgi-bin/my/emergencyurl")
		}
		else {
			print("/clicker/url/mm/url_expire not found")
		}
		if let data = Config.getJSON("/infrastructure/database/box/odkl-profiles/mapping") {
			let json = data as! [Int]
			for index in 0...15 {
				XCTAssertEqual(json[index], 1)
			}
			for index in 16...31 {
				XCTAssertEqual(json[index], 2)
			}
			if let ip: [String] = Config.get("/infrastructure/database/silverlike") {
				XCTAssertEqual(ip[0], "188.93.61.37:43500")
				XCTAssertEqual(ip[1], "43500")
				XCTAssertEqual(ip[2], "43500")
				XCTAssertEqual(ip[3], "43500;188.93.61.37:43500")
				XCTAssertEqual(ip[4], "43500")
				XCTAssertEqual(ip[5], "43500")
				XCTAssertEqual(ip[6], "43500;188.93.61.37:43500")
			}
		}
	    XCTAssertEqual(Config.get("/onlineconf/module/newraker_new/per_type_settings/TYPE_PHOTO/collage/enabled")! as Double, 100.0)
		XCTAssertFalse(Config.get("/monitoring/pinger/check-warnings"))
		XCTAssertFalse(Config.get("/monitoring/pinger/server/bury-fail-task"))
		XCTAssertFalse(Config.get("/negative/key"))
		var dict = [String: Any]()
		for (k, v) in try! Config.getModule("MYMAIL") {
			dict[k] = v
		}
		XCTAssertEqual(dict["Add_db_login"] as? String, "zzzQ")
	}

	func testMetaConf() {
		var st = stat()
		stat("/usr/local/etc/onlineconf/TREE.cdb", &st)
		XCTAssertEqual(st.st_mtim.tv_sec, Config.mtime)
		let olddir = Config.dir
		Config.dir = "Tests/OnlineConfTests/"
		defer { Config.dir = olddir }
		stat("Tests/OnlineConfTests/test.cdb", &st)
		let config = try! Config("test")
		XCTAssertEqual(st.st_mtim.tv_sec, config.mtime)
		sleep(1)
		let recheck = config.recheckTime
		XCTAssertFalse(config.reload())
		XCTAssertEqual(config.recheckTime, recheck)
		try! config.forceReload()
		XCTAssertNotEqual(config.recheckTime, recheck)
		XCTAssertEqual(st.st_mtim.tv_sec, config.mtime)
		XCTAssertEqual(1, config.get("/blogs/closed")! as Int)
	}

	static var allTests : [(String, (OnlineConfTests) -> () throws -> Void)] {
		return [
			("testLocalConf", testLocalConf),
			("testTreeConf", testTreeConf),
			("testMetaConf", testMetaConf),
		]
	}
}
