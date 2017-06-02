import XCTest
import Foundation
import Perl
@testable import OnlineConf
@testable import OnlineConfPerl

let perl: PerlInterpreter = {
	let perl = PerlInterpreter.new()
	boot(perl.pointer)
	return perl
}()

class OnlineConfPerlTests: XCTestCase {
	func testPerlConf() {
		XCTAssertEqual(try perl.eval("MR::OnlineConf->get('/blogs/closed')"), 1)
		XCTAssertEqual(try perl.eval("MR::OnlineConf->get('MYMAIL', 'Add_db_login')"), "zzzQ")
		XCTAssertEqual(try perl.eval("MR::OnlineConf->get('kotiki', 'kotiki_db_login')"), "alei")
		XCTAssertEqual(try perl.eval("MR::OnlineConf->get('/undef_key_from_tree', 404)"), 404)
		XCTAssertEqual(try perl.eval("MR::OnlineConf->get('MYMAIL', 'undef_key', 404)"), 404)
		XCTAssertEqual(try perl.eval("MR::OnlineConf->get('/undef_without_def')") ?? 404, 404)
		XCTAssertEqual(try perl.eval("MR::OnlineConf->get('/undef_without_def')") ?? 1000, 1000)
		XCTAssertEqual(try perl.eval("MR::OnlineConf->get('kotiki', 'undef_without_def')") ?? 404, 404)
		XCTAssertEqual(try perl.eval("MR::OnlineConf->get('/agent/friendship/check/macagent')->{check}"), 1)
		XCTAssertEqual(try perl.eval("MR::OnlineConf->get('/agent/friendship/check/macagent')->{and}"), 1)
		XCTAssertEqual(try perl.eval("MR::OnlineConf->instance->get('/blogs/closed')"), 1)
		XCTAssertEqual(try perl.eval("MR::OnlineConf->instance->getModule('MYMAIL')->{Add_db_login}"), "zzzQ")
	}

	func testPerlReload() {
		var st = stat()
		try! perl.eval("MR::OnlineConf->reload('MYMAIL')")
		guard let config = try? Config("MYMAIL")
		else { return }
		stat("/usr/local/etc/onlineconf/MYMAIL.cdb", &st)
		XCTAssertEqual(st.st_mtim.tv_sec, config.mtime)
		stat("/usr/local/etc/onlineconf/TREE.cdb", &st)
		XCTAssertEqual(st.st_mtim.tv_sec, Config.mtime)
		try! perl.eval("MR::OnlineConf->instance->reload('MYMAIL')")
	}

	static var allTests: [(String, (OnlineConfPerlTests) -> () throws -> Void)] {
		return [
			("testPerlConf", testPerlConf),
			("testPerlReload", testPerlReload),
		]
	}
}
