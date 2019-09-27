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
	override func setUp() {
		Config.dir = "Tests/OnlineConfTests/"
	}

	func testPerlConf() {
		XCTAssertEqual(try perl.eval("MR::OnlineConf->get('/blogs/closed')"), 1)
		XCTAssertEqual(try perl.eval("MR::OnlineConf->get('TREE', '/blogs/closed')"), 1)
		XCTAssertEqual(try perl.eval("MR::OnlineConf->get('/undef_key', 404)"), 404)
		XCTAssertEqual(try perl.eval("MR::OnlineConf->get('TREE', '/undef_key', 404)"), 404)
		XCTAssertNil(try perl.eval("MR::OnlineConf->get('/undef_without_def')") as String?)
		XCTAssertNil(try perl.eval("MR::OnlineConf->get('TREE', '/undef_without_def')") as String?)
		XCTAssertEqual(try perl.eval("MR::OnlineConf->get('/agent/friendship/check/macagent')->{check}"), 1)
		XCTAssertEqual(try perl.eval("MR::OnlineConf->get('/agent/friendship/check/macagent')->{and}"), 1)
		XCTAssertEqual(try perl.eval("MR::OnlineConf->instance->get('/blogs/closed')"), 1)
		XCTAssertEqual(try perl.eval("MR::OnlineConf->instance->getModule('TREE')->{'/blogs/closed'}"), "1")
	}

	func testPerlReload() {
		try! perl.eval("MR::OnlineConf->reload('TREE')")
		try! perl.eval("MR::OnlineConf->instance->reload('TREE')")
	}

	static var allTests: [(String, (OnlineConfPerlTests) -> () throws -> Void)] {
		return [
			("testPerlConf", testPerlConf),
			("testPerlReload", testPerlReload),
		]
	}
}
