import XCTest
import CCKV
@testable import OnlineConf

func errcv(arg : Optional<UnsafeMutableRawPointer>, path : Optional<UnsafePointer<CChar>>,
          call : Optional<UnsafePointer<CChar>>, num : CInt)
{
        let p = String(cString : path!)
        let c = String(cString : call!)
        print("Error num \(num), path \(p) and call \(c)" )
}

class OnlineConfTests: XCTestCase {
    func testExample() {
        let kind : CKVType = .cdb_format
        let mem : CKVMemory = .mmap
        let cfg = Config(path: "test.cdb", kind: kind, memory: mem, ecb: errcv, ecbarg: nil)
        let key = "/blogs/closed"
        let v : String? = cfg.getParam(key: key)
        if v != nil {
                print ("Value \(v!)")
        } else { print("Not found") }
   }


    static var allTests : [(String, (OnlineConfTests) -> () throws -> Void)] {
        return [
            ("testExample", testExample),
        ]
    }
}
