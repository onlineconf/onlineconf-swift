
import CCKV
import Foundation

public typealias ErrorCb = (String, String, Int32) -> Void

func err(path: String, call: String, num : Int32)
{
	print("Error num \(num), path \(path) and call \(call)" )
}

public class Config {

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

	public init(path: String, kind: Kind = Kind(.cdb, typed: true), memory: Memory = .mmap, ecb: @escaping ErrorCb) throws {
		self.path = path
		self.kind = kind
		self.memory = memory
		self.ecb = ecb
		self.kv = ckv_open(path, kind.type, ckv_try_mmap(memory.rawValue), {
				a,b,c,d in a!.assumingMemoryBound(to: ErrorCb.self).pointee(String(cString: b!), String(cString: c!), d)
				}, UnsafeMutablePointer(&self.ecb))
		if kv == nil  { throw ConfigError.failOpenConfig }
	}

	deinit {
		ckv_close(kv)
	}

	public func reload() throws -> Void {
		guard let kv = ckv_open(path, kind.type, ckv_try_mmap(memory.rawValue), {
				a,b,c,d in a!.assumingMemoryBound(to: ErrorCb.self).pointee(String(cString: b!), String(cString: c!), d)
				}, UnsafeMutablePointer(&self.ecb))
		else { throw ConfigError.failReloadConfig }
		self.kv = kv
	}

	public func get(_ key: String) -> String? {
		let param = getString(key)
			guard let vf = param else { return nil }
		return vf.0
	}

	public func get(_ key: String) -> [String]? {
		let param = getString(key)
		guard let vf = param else { return nil }
		return vf.0.characters.split(separator: ",").map(String.init)
	}

	public func get(_ key: String) -> Int? {
		let param = getString(key)
			guard let vf = param else { return nil }
		return Int(vf.0)
	}

	public func get(_ key: String) -> Bool {
		let param = getString(key)
		guard let vf = param else { return false }
		if vf.0.isEmpty || vf.0 == "0" { return false }
		return true
	}

	public func getJson(_ key: String) -> Any? {
		let vf = getData(key)
		let parsed = try? JSONSerialization.jsonObject(with: vf!.0)
		return parsed
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

	static public func getJson(_ key: String) -> Any? {
		return configTree.getJson(key)
	}

	private var kv: OpaquePointer?
	private let path: String
	private let kind: Kind
	private let memory: Memory
	private var ecb: ErrorCb
	static private var configTree = try! Config(path: "/usr/local/etc/onlineconf/TREE.cdb", ecb: err)

	private func getString(_ key: String) -> (String, String)? {
		guard let vf = getFromCKV(key) else { return nil }
		if vf.1 == "s" {
			let v_len = Int(vf.0.len)
			guard let c_v = vf.0.str else { return nil }
			guard let value = c_v.withMemoryRebound(to: UTF8.CodeUnit.self, capacity: v_len, {
				String._fromCodeUnitSequence(UTF8.self, input: UnsafeBufferPointer(start: $0, count: v_len))
				})
			else { return nil }
			return (value, vf.1)
		}
		else { return nil } /* may be throw exception */
	}

	private func getData(_ key: String) -> (Data, String)? {
		guard let vf = getFromCKV(key) else { return nil }
		if vf.1 == "j" {
			let v_len = Int(vf.0.len)
			guard let c_v = vf.0.str else { return nil }
			let pointer = UnsafeMutablePointer(mutating: c_v)
			let value = Data(bytesNoCopy: pointer, count: v_len, deallocator: .none)
			return (value, vf.1)
		}
		else { return nil } /* may be throw exception */
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

		let f_len = Int(f.len)
		guard let c_f = f.str else { return nil }
		guard let format = c_f.withMemoryRebound(to: UTF8.CodeUnit.self, capacity: f_len, {
			String._fromCodeUnitSequence(UTF8.self, input: UnsafeBufferPointer(start: $0, count: f_len))
		})
		else { return nil }
		return (v, format)
	}
}

