
import CCKV
import Foundation

private func errorCallBack(path: String, call: String, num: Int) {
	print("Error num \(num), path \(path) and call \(call)")
}

private func cErrorCallBack(_ ecb: UnsafeMutableRawPointer?, _ path: UnsafePointer<CChar>?, _ call: UnsafePointer<CChar>?, _ num: Int32) -> Void {
	ecb!.assumingMemoryBound(to: Config.ErrorCallBack.self).pointee(String(cString: path!), String(cString: call!), Int(num))
}

public class Config {

	public typealias ErrorCallBack = (String, String, Int) -> Void

	public struct Kind {

		public enum Format {
			case text
			case cdb
		}

		public init(_ format : Format, typed : Bool) {
			if typed {
				switch format {
					case .text: type = CKV_TEXT_WITH_FORMAT
					case .cdb: type = CKV_CDB_BYTEFORMAT
				}
			}
			else {
				switch format {
					case .text: type = CKV_TEXT_NOFORMAT
					case .cdb: type = CKV_CDB_NOFORMAT
				}
			}
		}

		public var format: Format {
			switch type {
				case CKV_TEXT_WITH_FORMAT: return .text
				case CKV_TEXT_NOFORMAT: return .text
				case CKV_CDB_BYTEFORMAT: return .cdb
				case CKV_CDB_NOFORMAT: return .cdb
				default: return .cdb
			}
		}

		public var typedValues: Bool {
			return type == CKV_TEXT_WITH_FORMAT || type == CKV_CDB_BYTEFORMAT
		}

		let type: ckv_kind
	}

	public enum Memory {
		case mmap
		case mmapMalloc
		case malloc

		var rawValue: UInt32 {
			let type: ckv_try_mmap
			switch self {
				case .mmap: type = CKV_MMAP_MALLOC_ON_FAIL
				case .mmapMalloc: type = CKV_MMAP_OR_FAIL
				case .malloc: type = CKV_MALLOC_ONLY
			}
			return type.rawValue
		}
	}
	
	public init(path: String, kind: Kind = Kind(.cdb, typed: true), memory: Memory = .mmap, ecb: @escaping ErrorCallBack = errorCallBack) throws {
		self.ecb = ecb
		guard let kv = ckv_open(path, kind.type, ckv_try_mmap(memory.rawValue), cErrorCallBack, UnsafeMutablePointer(&self.ecb))
		else  { throw ConfigError.failOpenConfig }
		self.kv = kv
		self.path = path
		self.kind = kind
		self.memory = memory
	}

	deinit {
		ckv_close(kv)
	}

	public func reload() throws -> Void {
		guard let kv = ckv_open(path, kind.type, ckv_try_mmap(memory.rawValue), cErrorCallBack, UnsafeMutablePointer(&self.ecb))
		else { throw ConfigError.failReloadConfig }
		ckv_close(self.kv)
		self.kv = kv
	}

	public func get(_ key: String) -> String? {
		return getRawString(key)
	}

	public func get(_ key: String) -> [String]? {
		guard let rawValue = getRawString(key)
		else { return nil }
		return rawValue.characters.split(separator: ",").map(String.init)
	}

	public func get(_ key: String) -> Int? {
		guard let rawValue = getRawString(key)
		else { return nil }
		return Int(rawValue)
	}

	public func get(_ key: String) -> Bool {
		guard let rawValue = getRawString(key)
		else { return false }
		if rawValue.isEmpty || rawValue == "0" { return false }
		return true
	}

	public func getJSON(_ key: String) -> Any? {
		guard let rawValue = getRawData(key)
		else { return nil }
		if let json = try? JSONSerialization.jsonObject(with: rawValue) {
			return json
		}
		self.ecb(key, "Can't convert string to JSON", -1)
		return nil
	}

	public var modify: time_t {
		return ckv_fstat(kv)!.pointee.st_mtim.tv_sec
	}

	static public func reload() throws -> Void {
		try configTree.reload()
	}

	static public func get(_ key: String) -> String? {
		return configTree.get(key)
	}

	static public func get(_ key: String) -> [String]? {
		return configTree.get(key)
	}

	static public func get(_ key: String) -> Int? {
		return configTree.get(key)
	}

	static public func get(_ key: String) -> Bool {
		return configTree.get(key)
	}

	static public func getJSON(_ key: String) -> Any? {
		return configTree.getJSON(key)
	}

	static public var modify: time_t {
		return configTree.modify
	}

	private var kv: OpaquePointer
	private let path: String
	private let kind: Kind
	private let memory: Memory
	private var ecb: ErrorCallBack
	static private var configTree = try! Config(path: "/usr/local/etc/onlineconf/TREE.cdb", ecb: errorCallBack)

	private func getRawString(_ key: String) -> String? {
		guard let vf = getFromCKV(key) else { return nil }
		if vf.1 == "s" {
			let vLen = Int(vf.0.len)
			guard let cValue = vf.0.str else {
				self.ecb(key, "getRawString: Value is NULL", -1)
				return nil
			}
			guard let value = cValue.withMemoryRebound(to: UTF8.CodeUnit.self, capacity: vLen, {
				String._fromCodeUnitSequence(UTF8.self, input: UnsafeBufferPointer(start: $0, count: vLen))
			})
			else {
				self.ecb(key, "getRawString: Value can't convert to Swift string", -1)
				return nil
			}
			return value
		}
		else {
			self.ecb(key, "getRawString: Format is invalid", -1)
			return nil
		}
	}

	private func getRawData(_ key: String) -> Data? {
		guard let vf = getFromCKV(key) else { return nil }
		if vf.1 == "j" {
			let vLen = Int(vf.0.len)
			guard let cValue = vf.0.str else {
				self.ecb(key, "getRawData: Value is NULL", -1)
				return nil
			}
			let pointer = UnsafeMutablePointer(mutating: cValue)
			let value = Data(bytesNoCopy: pointer, count: vLen, deallocator: .none)
			return value
		}
		else {
			self.ecb(key, "getRawData: Format is invalid", -1)
			return nil
		}
	}

	private func getFromCKV(_ key: String) -> (ckv_str, String)? {
		var f = ckv_str()
		var v = ckv_str()
		ContiguousArray(key.utf8).withUnsafeBufferPointer {
			let count = $0.count
				_ = $0.baseAddress!.withMemoryRebound(to: Int8.self, capacity: count) {
					ckv_key_get(kv, UnsafePointer<Int8>($0), Int32(count), &v, &f)
				}
		}

		guard let cFormat = f.str else { return nil }
		let fLen = Int(f.len)
		guard let format = cFormat.withMemoryRebound(to: UTF8.CodeUnit.self, capacity: fLen, {
			String._fromCodeUnitSequence(UTF8.self, input: UnsafeBufferPointer(start: $0, count: fLen))
		})
		else {
			self.ecb(key, "getFromCKV: Can't convert to Swift string", -1);
			return nil
		}
		return (v, format)
	}
}
