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

		func decodeString() throws -> String {
			guard let str = String._fromCodeUnitSequence(UTF8.self, input: data) else {
				throw DecodeError.invalidUTF8
			}
			return str
		}

		func decodeJSON() throws -> Any {
			let start = UnsafeMutablePointer(mutating: data.baseAddress!.assumingMemoryBound(to: UTF8.CodeUnit.self))
			let jsonData = Data(bytesNoCopy: start, count: data.count, deallocator: .none)
			guard let json = try? JSONSerialization.jsonObject(with: jsonData) else {
				throw DecodeError.invalidJSON
			}
			return json
		}

		func decode() throws -> Any {
			switch format {
				case .text: return try decodeString()
				case .json: return try decodeJSON()
				case .cbor: throw DecodeError.cborUnsupported
			}
		}

		enum DecodeError : String, Swift.Error, CustomStringConvertible {
			case invalidUTF8 = "Invalid UTF-8"
			case invalidJSON = "Invalid JSON"
			case cborUnsupported = "CBOR is unsupported yet"
			var description: String { return rawValue }
		}
	}

	public enum Error : Swift.Error {
		case openFailure
		case lockedByIterator
	}

	public typealias ErrorCallback = (String, String, Int) -> Void

	private static func defaultErrorCallback(path: String, call: String, num: Int) {
		print("OnlineConf error: \(path) - \(call) [\(num)]", to: &errStream)
	}

	public let name: String
	var kv: OpaquePointer
	var path: String
	let kind: Kind
	let memory: Memory
	var onError: ErrorCallback

	var iteratorCount = 0

	static var dir = "/usr/local/etc/onlineconf/" {
		didSet { try? forceReload() }
	}
	
	public init(_ module: String = "TREE", format: FileFormat = .cdb, typed: Bool = true, memory: Memory = .mmapMalloc, onError: @escaping ErrorCallback = Config.defaultErrorCallback) throws {
		name = module
		path = Config.dir + module + format.ext
		kind = Kind(format: format, typed: typed)
		self.memory = memory
		self.onError = onError
		guard let kv = ckv_open(path, kind.rawValue, memory.rawValue, errcb, UnsafeMutablePointer(&self.onError)) else {
			throw Error.openFailure
		}
		self.kv = kv
	}

	deinit {
		ckv_close(kv)
	}

	public static var checkInterval: Int? = 5

	var recheckTime: Int? = checkInterval.map { time(nil) + $0 }

	public func forceReload() throws {
		guard iteratorCount == 0 else {
			throw Error.lockedByIterator
		}
		path = Config.dir + name + kind.format.ext
		guard let kv = ckv_open(path, kind.rawValue, memory.rawValue, errcb, UnsafeMutablePointer(&self.onError)) else {
			throw Error.openFailure
		}
		ckv_close(self.kv)
		self.kv = kv
		recheckTime = Config.checkInterval.map { time(nil) + $0 }
		stringCache = [:]
		stringsCache = [:]
		jsonCache = [:]
		callOnReload()
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

	@discardableResult
	private func periodicReload() -> Bool {
		guard let rt = recheckTime, time(nil) > rt else { return false }
		defer { recheckTime = Config.checkInterval.map { time(nil) + $0 } }
		return reload()
	}

	public func withPeriodicReload<R>(_ body: (Bool) throws -> R) rethrows -> R {
		let reloaded = periodicReload()
		let rt = recheckTime
		recheckTime = nil
		defer { recheckTime = rt }
		return try body(reloaded)
	}

	var stringCache = [UnsafeRawPointer: String?]()

	public func get(_ key: String) -> String? {
		return withUnsafeValue(key: key) { value in
			if let v = stringCache[value.data.baseAddress!] {
				return v
			} else {
				let val: String?
				switch value.format {
					case .cbor:
						onError(key, "Invalid format \(value.format) for String", -1)
						val = nil
					default:
						do {
							val = try value.decodeString()
						} catch {
							onError(key, String(describing: error), -1)
							val = nil
						}
				}
				stringCache[value.data.baseAddress!] = val
				return val
			}
		}
	}

	var stringsCache = [UnsafeRawPointer: [String]?]()

	public func get(_ key: String) -> [String]? {
		return withUnsafeValue(key: key) { value in
			if let v = stringsCache[value.data.baseAddress!] {
				return v
			} else {
				let val: [String]?
				switch value.format {
					case .text:
						do {
							let str = try value.decodeString()
							val = str.characters.split(separator: ",").map(String.init)
						} catch {
							onError(key, String(describing: error), -1)
							val = nil
						}
					case .json:
						do {
							if let v = try value.decodeJSON() as? [String] {
								val = v
							} else {
								onError(key, "Invalid json structure for [String]", -1)
								val = nil
							}
						} catch {
							onError(key, String(describing: error), -1)
							val = nil
						}
					case .cbor:
						onError(key, "CBOR is unsupported yet", -1)
						val = nil
				}
				stringsCache[value.data.baseAddress!] = val
				return val
			}
		}
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
		return withUnsafeValue(key: key) {
			switch $0.data.count {
				case 0:
					return false
				case 1:
					return $0.data[0] != UInt8(ascii: "0")
				default:
					return true
			}
		} ?? false
	}

	public func withUnsafeValue<R>(key: String, body: (UnsafeValue) throws -> R?) rethrows -> R? {
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

	var jsonCache = [UnsafeRawPointer: Any?]()

	public func getJSON(_ key: String) -> Any? {
		return withUnsafeValue(key: key) { value in
			if let v = jsonCache[value.data.baseAddress!] {
				return v
			} else {
				let val: Any?
				switch value.format {
					case .json:
						do {
							val = try value.decodeJSON()
						} catch {
							onError(key, String(describing: error), -1)
							val = nil
						}
					case .cbor:
						onError(key, "CBOR is unsupported yet", -1)
						val = nil
					default:
						onError(key, "Format is not JSON: \(value.format)", -1)
						val = nil
				}
				jsonCache[value.data.baseAddress!] = val
				return val
			}
		}
	}

	public var mtime: time_t {
		return ckv_fstat(kv)!.pointee.st_mtim.tv_sec
	}

	public static let tree = try! getModule("TREE")

	public static func get(_ key: String) -> String? {
		return tree.get(key)
	}

	public static func get(_ key: String) -> [String]? {
		return tree.get(key)
	}

	public static func get(_ key: String) -> Int? {
		return tree.get(key)
	}

	public static func get(_ key: String) -> Double? {
		return tree.get(key)
	}

	public static func get(_ key: String) -> Bool {
		return tree.get(key)
	}

	public static func withUnsafeValue<R>(key: String, body: (UnsafeValue) throws -> R?) rethrows -> R? {
		return try tree.withUnsafeValue(key: key, body: body)
	}

	public static func getJSON(_ key: String) -> Any? {
		return tree.getJSON(key)
	}

	public static var mtime: time_t {
		return tree.mtime
	}

	static var configs: [String: Config] = [:]

	public static func getModule(_ module: String) throws -> Config {
		if let config = Config.configs[module] {
			return config
		}
		let config = try Config(module)
		Config.configs[module] = config
		return config
	}

	public static func getModule(ifLoaded module: String) -> Config? {
		return Config.configs[module]
	}

	@discardableResult
	public static func reload() -> Bool {
		var reloaded = false
		for (_, c) in configs {
			if c.reload() {
				reloaded = true
			}
		}
		return reloaded
	}

	public static func forceReload() throws {
		var firstError: Swift.Error?
		for (_, c) in configs {
			do {
				try c.forceReload()
			} catch {
				if firstError == nil {
					firstError = error
				}
			}
		}
		if let error = firstError {
			throw error
		}
	}

	private static var onReloadCallbacks = [(Config) -> Void]()
	private var onReloadCallbacks = [(Config) -> Void]()

	public static func onReload(_ body: @escaping (Config) -> Void) {
		onReloadCallbacks.append(body)
	}

	public func onReload(_ body: @escaping (Config) -> Void) {
		onReloadCallbacks.append(body)
	}

	private func callOnReload() {
		for callback in onReloadCallbacks {
			callback(self)
		}
		for callback in Config.onReloadCallbacks {
			callback(self)
		}
	}
}

extension Config : Sequence {
	public func makeIterator() -> Iterator {
		return Iterator(self)
	}

	public final class Iterator : IteratorProtocol {
		let config: Config
		var iter = ckv_iter()

		public init(_ config: Config) {
			self.config = config
			config.iteratorCount += 1
			ckv_iter_init(config.kv, &iter)
		}

		deinit {
			config.iteratorCount -= 1
		}

		public func withNextUnsafeValue<V>(_ body: (Config.UnsafeValue) throws -> V) -> (String, V)? {
			while true {
				guard ckv_iter_next(config.kv, &iter) != 0 else { return nil }
				let key = String._fromCodeUnitSequenceWithRepair(UTF8.self, input: UnsafeRawBufferPointer(start: iter.key.str, count: Int(iter.key.len))).0
				let format = Config.ValueFormat(rawValue: UnsafeRawBufferPointer(start: iter.fmt.str, count: Int(iter.fmt.len)), fileFormat: config.kind.format)
				let value = Config.UnsafeValue(format: format, data: UnsafeRawBufferPointer(start: iter.val.str, count: Int(iter.val.len)))
				do {
					return (key, try body(value))
				} catch {
					config.onError(key, String(describing: error), -1)
				}
			}
		}

		public func next() -> (String, Any)? {
			return withNextUnsafeValue({ try $0.decode() })
		}
	}
}

private func errcb(_ onError: UnsafeMutableRawPointer?, _ path: UnsafePointer<CChar>?, _ call: UnsafePointer<CChar>?, _ num: Int32) -> Void {
	onError?.assumingMemoryBound(to: Config.ErrorCallback.self).pointee(String(cString: path!), String(cString: call!), Int(num))
}

struct StderrOutputStream: TextOutputStream {
	mutating func write(_ string: String) { fputs(string, stderr) }
}

var errStream = StderrOutputStream()
