import XCTest
import Foundation
import Perl
@testable import OnlineConf
@testable import OnlineConfPerl

class OnlineConfPerlTests: XCTestCase {
		func testPerlConf() {
		let perl = PerlInterpreter()
		perl.withUnsafeInterpreterPointer {
			UnsafeInterpreter.current = $0
			boot($0)
		}
		XCTAssertEqual(try perl.eval("MR::OnlineConf->get('/blogs/closed')"), 1)
		XCTAssertEqual(try perl.eval("MR::OnlineConf->get('MYMAIL', 'Add_db_login')"), "zzzQ")
		XCTAssertEqual(try perl.eval("MR::OnlineConf->get('kotiki', 'kotiki_db_login')"), "alei")
		XCTAssertEqual(try perl.eval("MR::OnlineConf->get('/undef_key_from_tree', 404)"), 404)
		XCTAssertEqual(try perl.eval("MR::OnlineConf->get('MYMAIL', 'undef_key', 404)"), 404)
		XCTAssertEqual(try perl.eval("MR::OnlineConf->get('/undef_without_def')") ?? 404, 404)
		XCTAssertEqual(try perl.eval("MR::OnlineConf->get('kotiki', 'undef_without_def')") ?? 404, 404)
		XCTAssertEqual(try perl.eval("MR::OnlineConf->get('/agent/friendship/check/macagent')->{check}"), 1)
		XCTAssertEqual(try perl.eval("MR::OnlineConf->get('/agent/friendship/check/macagent')->{and}"), 1)
	}

	func testPerlReload() {
		let perl = PerlInterpreter()
		perl.withUnsafeInterpreterPointer {
			UnsafeInterpreter.current = $0
			boot($0)
		}
		var st = stat()
		try! perl.eval("MR::OnlineConf->reload('MYMAIL')")
		guard let config = try? Config(module: "MYMAIL")
		else { return }
		stat("/usr/local/etc/onlineconf/MYMAIL.cdb", &st)
		XCTAssertEqual(st.st_mtim.tv_sec, config.mtime)
		stat("/usr/local/etc/onlineconf/TREE.cdb", &st)
		XCTAssertEqual(st.st_mtim.tv_sec, Config.mtime)
	}

	static var allTests: [(String, (OnlineConfPerlTests) -> () throws -> Void)] {
		return [
			("testPerlConf", testPerlConf),
			("testPerlReload", testPerlReload),
		]
	}
}
