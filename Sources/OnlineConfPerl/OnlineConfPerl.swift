
import OnlineConf
import Perl

@_cdecl("boot_MR__OnlineConf")
public func boot(_ p: UnsafeInterpreterPointer) {
	try! p.pointee.require("JSON::XS")
	try! p.pointee.require("CBOR::XS")
	OnlineConfPerl.initialize(perl: p)
}

final class OnlineConfPerl : PerlObject, PerlNamedClass {
	static let perlClassName = "MR::OnlineConf"

	static let tree = try! ConfigCache("TREE")
	static var caches = [PerlScalar("TREE"): tree]

	static let slash = UInt8(ascii: "/")

	static func initialize(perl: UnsafeInterpreterPointer = UnsafeInterpreter.current) {
		Config.onReload(onReload)

		// mympop & qm compatibility
		try! perl.pointee.eval("{ package MR::OnlineConf; my %instances; sub instance { ref $_[0] ? $_[0] : ($instances{$_[0]} ||= $_[0]->_new_instance()) } }")

		// mympop & qm compatibility
		createPerlMethod("_new_instance") {
			(classname: String, options: [String: PerlScalar]) -> PerlScalar in
			if !(options["reload"].map(Bool.init) ?? true) {
				Config.checkInterval = nil
			}
			return try perl.pointee.eval("bless { cfg => { check_interval => 5 } }, '\(classname)'")
		}

		createPerlMethod("reload") {
			() -> Void in
			Config.reload()
		}

		createPerlMethod("get") {
			(_: PerlScalar, args: [PerlScalar]) throws -> PerlScalar in
			var args = ArraySlice(args)
			guard let moduleOrKey = args.popFirst() else { throw Error.invalidArguments }
			let isKey = moduleOrKey.withUnsafeBytes { $0.load(as: UInt8.self) == slash }
			let cache: ConfigCache
			let key: PerlScalar
			if isKey {
				cache = tree
				key = moduleOrKey
			} else {
				cache = try getCache(moduleOrKey)
				guard let k = args.popFirst() else { throw Error.invalidArguments }
				key = k
			}
			let value: PerlScalar = try cache.config.withPeriodicReload { reloaded in
				if !reloaded, let v = cache.cache[key] {
					return v
				} else {
					let value = try cache.config.withUnsafeValue(key: try String(key), body: decodeValue) ?? PerlScalar()
					cache.cache[key] = value
					return value
				}
			}
			return value ?? args.popFirst() ?? value
		}

		createPerlMethod("getModule") {
			(_: PerlScalar, module: PerlScalar) throws -> PerlScalar in
			let cache = try getCache(module)
			if let m = cache.module {
				return m
			}
			let hash = PerlHash()
			let iterator = Config.Iterator(cache.config)
			while let (key, value) = iterator.withNextUnsafeValue(decodeValue) {
				hash[key] = value
			}
			let result = PerlScalar(hash)
			cache.module = result
			return result
		}

		// mympop & qm compatibility
		createPerlMethod("preload") {
			() -> Void in
			Config.reload()
		}
	}

	private static func getCache(_ module: PerlScalar) throws -> ConfigCache {
		if let cache = caches[module] {
			return cache
		} else {
			let cache = try ConfigCache(try String(module))
			caches[module] = cache
			return cache
		}
	}

	private static func decodeValue(_ value: Config.UnsafeValue) throws -> PerlScalar {
		switch value.format {
			case .text: return PerlScalar(value.data, containing: .characters)
			case .json: return try PerlSub.call("JSON::XS::decode_json", PerlScalar(value.data, containing: .bytes))
			case .cbor: return try PerlSub.call("CBOR::XS::decode_cbor", PerlScalar(value.data, containing: .bytes))
		}
	}

	private static func onReload(_ config: Config) {
		let module = PerlScalar(config.name)
		caches[module]?.clear()
	}

	enum Error : Swift.Error {
		case invalidArguments
	}
}

final class ConfigCache {
	let config: Config
	var cache: [PerlScalar: PerlScalar]
	var module: PerlScalar?

	init(_ name: String) throws {
		config = try Config.getModule(name)
		cache = [:]
	}

	func clear() {
		cache = [:]
		module = nil
	}
}
