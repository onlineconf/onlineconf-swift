
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

	static var instances = PerlHash()
	static let tree = PerlHash()
	static var cache: PerlHash = ["TREE": PerlScalar(tree)]
	static var moduleCache = [String: PerlScalar]()

	static let slash = UInt8(ascii: "/")

	static func initialize(perl: UnsafeInterpreterPointer = UnsafeInterpreter.current) {
		Config.onReload(onReload)

		// mympop & qm compatibility
		createPerlMethod("instance") {
			(classname: PerlScalar) -> PerlScalar in
			if let inst = instances[classname] {
				return inst
			} else {
				let inst: PerlScalar = try perl.pointee.call(method: "_new_instance", args: CollectionOfOne(.some(classname)))
				instances[classname] = inst
				return inst
			}
		}

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
			let module: String
			let cacheModule: PerlHash?
			let config: Config
			let key: PerlScalar
			if isKey {
				module = "TREE"
				cacheModule = tree
				config = Config.tree
				key = moduleOrKey
			} else {
				module = try String(moduleOrKey)
				guard let k = args.popFirst() else { throw Error.invalidArguments }
				cacheModule = try cache.fetch(moduleOrKey)
				config = try Config.getModule(module)
				key = k
			}
			let value: PerlScalar = try config.withPeriodicReload { reloaded in
				if !reloaded, let v = cacheModule?[key] {
					return v
				} else {
					let value = try config.withUnsafeValue(key: try String(key), body: decodeValue) ?? PerlScalar()
					if cache[module] != nil {
						try PerlHash(cache[module]!)[key] = value
					} else {
						let hv = PerlHash()
						hv[key] = value
						cache[module] = PerlScalar(hv)
					}
					return value
				}
			}
			return value ?? args.popFirst() ?? value
		}

		createPerlMethod("getModule") {
			(_: PerlScalar, module: String) throws -> PerlScalar in
			if let c = moduleCache[module] {
				return c
			}
			let hash = PerlHash()
			let config = try Config.getModule(module)
			let iterator = Config.Iterator(config)
			while let (key, value) = iterator.withNextUnsafeValue(decodeValue) {
				hash[key] = value
			}
			let result = PerlScalar(hash)
			moduleCache[module] = result
			return result
		}

		// mympop & qm compatibility
		createPerlMethod("preload") {
			() -> Void in
			Config.reload()
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
		try! (cache.fetch(config.name) as PerlHash?)?.clear()
		moduleCache[config.name] = nil
	}

	enum Error : Swift.Error {
		case invalidArguments
	}
}
