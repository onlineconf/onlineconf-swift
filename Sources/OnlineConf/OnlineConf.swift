import CCKV
import Foundation

public final class Config {
	public enum FileFormat {
		case text
		case cdb

		var ext: String {
			switch self {
				case .text: return ".conf"
				case .cdb: return ".cdb"
			}
		}
	}

	struct Kind : RawRepresentable {
		let rawValue: ckv_kind

		init(rawValue: ckv_kind) {
			self.rawValue = rawValue
		}

		init(format: FileFormat, typed: Bool) {
			switch (format, typed) {
				case (.text, true): rawValue = CKV_TEXT_WITH_FORMAT
				case (.cdb, true): rawValue = CKV_CDB_BYTEFORMAT
				case (.text, false): rawValue = CKV_TEXT_NOFORMAT
				case (.cdb, false): rawValue = CKV_CDB_NOFORMAT
			}
		}

		var format: FileFormat {
			switch rawValue {
				case CKV_TEXT_WITH_FORMAT: return .text
				case CKV_TEXT_NOFORMAT: return .text
				case CKV_CDB_BYTEFORMAT: return .cdb
				case CKV_CDB_NOFORMAT: return .cdb
				default: return .cdb
			}
		}

		var typed: Bool {
			return rawValue == CKV_TEXT_WITH_FORMAT || rawValue == CKV_CDB_BYTEFORMAT
		}
	}

	public enum Memory : RawRepresentable {
		case mmapMalloc
		case mmap
		case malloc

		public init(rawValue: ckv_try_mmap) {
			switch rawValue {
				case CKV_MMAP_MALLOC_ON_FAIL: self = .mmapMalloc
				case CKV_MMAP_OR_FAIL: self = .mmap
				case CKV_MALLOC_ONLY: self = .malloc
				default: fatalError("impossible")
			}
		}

		public var rawValue: ckv_try_mmap {
			switch self {
				case .mmapMalloc: return CKV_MMAP_MALLOC_ON_FAIL
				case .mmap: return CKV_MMAP_OR_FAIL
				case .malloc: return CKV_MALLOC_ONLY
			}
		}
	}

	public enum ValueFormat {
		case text
		case json
		case cbor

		private static let c = Int8(UnicodeScalar("c").value)
		private static let j = Int8(UnicodeScalar("j").value)

		init(rawValue: UnsafeRawBufferPointer, fileFormat: FileFormat) {
			switch fileFormat {
				case .text:
					if rawValue.count == 4 && memcmp(rawValue.baseAddress!, "JSON", 4) == 0 {
						self = .json
					} else {
						self = .text
					}
				case .cdb:
					if rawValue.count == 1 {
						switch rawValue.baseAddress!.load(as: Int8.self) {
							case ValueFormat.c: self = .cbor
							case ValueFormat.j: self = .json
							default: self = .text
						}
					} else {
						self = .text
					}
			}
		}
	}

	public struct UnsafeValue {
		public let format: ValueFormat
		public let data: UnsafeRawBufferPointer
	}

	public enum Error : Swift.Error {
		case openFailure
	}

	public typealias ErrorCallback = (String, String, Int) -> Void

	private static func defaultErrorCallback(path: String, call: String, num: Int) {
		print("OnlineConf error: \(path) - \(call) [\(num)]", to: &errStream)
	}

	private var kv: OpaquePointer
	private let path: String
	private let kind: Kind
	private let memory: Memory
	private var onError: ErrorCallback

	static var dir = "/usr/local/etc/onlineconf/"
	
	public convenience init(module: String, format: FileFormat = .cdb, typed: Bool = true, memory: Memory = .mmapMalloc, onError: @escaping ErrorCallback = Config.defaultErrorCallback) throws {
		let path = Config.dir + module + format.ext
		try self.init(path: path, kind: Kind(format: format, typed: typed), memory: memory, onError: onError)
	}

	init(path: String, kind: Kind = Kind(format: .cdb, typed: true), memory: Memory = .mmapMalloc, onError: @escaping ErrorCallback = Config.defaultErrorCallback) throws {
		self.onError = onError
		guard let kv = ckv_open(path, kind.rawValue, memory.rawValue, errcb, UnsafeMutablePointer(&self.onError)) else {
			throw Error.openFailure
		}
		self.kv = kv
		self.path = path
		self.kind = kind
		self.memory = memory
	}

	deinit {
		ckv_close(kv)
	}

	public static var checkInterval: Int? = 5

	var recheckTime: Int? = checkInterval.map { time(nil) + $0 }

	public func forceReload() throws {
		guard let kv = ckv_open(path, kind.rawValue, memory.rawValue, errcb, UnsafeMutablePointer(&self.onError)) else {
			throw Error.openFailure
		}
		ckv_close(self.kv)
		self.kv = kv
		recheckTime = Config.checkInterval.map { time(nil) + $0 }
	}

	@discardableResult
	public func reload() -> Bool {
		var st = stat()
		guard stat(path, &st) == 0 else { return false }
		guard st.st_mtim.tv_sec > mtime else { return false }
		do {
			try forceReload()
			return true
		} catch {
			onError("", "Failed to reload \(path): \(error)", -1)
			return false
		}
	}

	private func periodicReload() {
		guard let rt = recheckTime, time(nil) > rt else { return }
		reload()
	}

	public func get(_ key: String) -> String? {
		return withUnsafeValue(key: key) { value in
			switch value.format {
				case .cbor:
					onError(key, "Invalid format \(value.format) for String", -1)
					return nil
				default:
					guard let str = String._fromCodeUnitSequence(UTF8.self, input: value.data) else {
						onError(key, "Invalid UTF-8", -1)
						return nil
					}
					return str
			}
		}
	}

	public func get(_ key: String) -> [String]? {
		guard let str: String = get(key) else { return nil }
		return str.characters.split(separator: ",").map(String.init)
	}

	public func get(_ key: String) -> Int? {
		guard let str: String = get(key) else { return nil }
		guard let int = Int(str) else {
			onError(key, "Value is not an integer: \(str)", -1)
			return nil
		}
		return int
	}

	public func get(_ key: String) -> Double? {
		guard let str: String = get(key) else { return nil }
		guard let dbl = Double(str) else {
			onError(key, "Value is not a double: \(str)", -1)
			return nil
		}
		return dbl
	}

	public func get(_ key: String) -> Bool {
		guard let str: String = get(key) else { return false }
		return !(str.isEmpty || str == "0")
	}

	public func withUnsafeValue<R>(key: String, _ body: (UnsafeValue) throws -> R?) rethrows -> R? {
		periodicReload()

		var fmt = ckv_str()
		var val = ckv_str()
		let found = ContiguousArray(key.utf8).withUnsafeBufferPointer { buf in
			buf.baseAddress!.withMemoryRebound(to: Int8.self, capacity: buf.count) {
				ckv_key_get(kv, $0, Int32(buf.count), &val, &fmt)
			}
		}
		guard found == 1 else { return nil }

		let format = ValueFormat(rawValue: UnsafeRawBufferPointer(start: fmt.str, count: Int(fmt.len)), fileFormat: kind.format)
		let value = UnsafeValue(format: format, data: UnsafeRawBufferPointer(start: val.str, count: Int(val.len)))
		return try body(value)
	}

	public func getJSON(_ key: String) -> Any? {
		return withUnsafeValue(key: key) { value in
			switch value.format {
				case .json:
					let start = UnsafeMutablePointer(mutating: value.data.baseAddress!.assumingMemoryBound(to: UTF8.CodeUnit.self))
					let data = Data(bytesNoCopy: start, count: value.data.count, deallocator: .none)
					guard let json = try? JSONSerialization.jsonObject(with: data) else {
						onError(key, "Invalid JSON", -1)
						return nil
					}
					return json
				case .cbor:
					onError(key, "CBOR is unsupported yet", -1)
					return nil
				default:
					onError(key, "Format is not JSON: \(value.format)", -1)
					return nil
			}
		}
	}

	public var mtime: time_t {
		return ckv_fstat(kv)!.pointee.st_mtim.tv_sec
	}

	static private var configTree = try! getModule("TREE")

	static public func reload() -> Bool {
		return configTree.reload()
	}

	static public func forceReload() throws {
		try configTree.forceReload()
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

	static public func get(_ key: String) -> Double? {
		return configTree.get(key)
	}

	static public func get(_ key: String) -> Bool {
		return configTree.get(key)
	}

	static public func getJSON(_ key: String) -> Any? {
		return configTree.getJSON(key)
	}

	static public var mtime: time_t {
		return configTree.mtime
	}

	static var configs: [String: Config] = [:]

	public static func getModule(_ module: String) throws -> Config {
		if let config = Config.configs[module] {
			return config
		}
		let config = try Config(module: module)
		Config.configs[module] = config
		return config
	}

	public static func getModule(ifLoaded module: String) -> Config? {
		return Config.configs[module]
	}
}

private func errcb(_ onError: UnsafeMutableRawPointer?, _ path: UnsafePointer<CChar>?, _ call: UnsafePointer<CChar>?, _ num: Int32) -> Void {
	onError?.assumingMemoryBound(to: Config.ErrorCallback.self).pointee(String(cString: path!), String(cString: call!), Int(num))
}

struct StderrOutputStream: TextOutputStream {
	mutating func write(_ string: String) { fputs(string, stderr) }
}

var errStream = StderrOutputStream()
