
import OnlineConf
import Perl

@_cdecl("boot_MR__OnlineConf")
public func boot(_ p: UnsafeInterpreterPointer) {
	try! p.pointee.require("JSON::XS")
	try! p.pointee.require("CBOR::XS")
	OnlineConfPerl.initialize(perl: p)
}

final class OnlineConfPerl : PerlBridgedObject, PerlNamedClass {
	static let perlClassName = "MR::OnlineConf"

	static var instance = PerlScalar(OnlineConfPerl())
	static var instances = [String: PerlScalar]()
	static var cache = [String: [String: PerlScalar?]]()
	static var moduleCache = [String: PerlScalar]()

	static func initialize(perl: UnsafeInterpreterPointer = UnsafeInterpreter.current) {
		createPerlMethod("instance") {
			(classname: String) -> PerlScalar in
			return try instances[classname] ?? perl.pointee.call(method: "_new_instance", args: CollectionOfOne(.some(classname)))
		}

		// mympop & qm compatibility
		createPerlMethod("_new_instance") {
			(classname: String, options: [String: PerlScalar]) -> PerlScalar in
			if !(options["reload"].map(Bool.init) ?? true) {
				Config.checkInterval = nil
			}
			instances[classname] = instance
			return instance
		}

		createPerlMethod("reload") {
			() -> Void in
			if Config.reload() {
				cache = [:]
				moduleCache = [:]
			}
		}

		createPerlMethod("get") {
			(_: PerlScalar, args: [PerlScalar]) throws -> PerlScalar in
			var args = ArraySlice(args)
			guard let moduleOrKey = try args.popFirst().map({ try String($0) }) else {
				throw Error.invalidArguments
			}
			let module: String
			let key: String
			if moduleOrKey.characters.first == "/" {
				module = "TREE"
				key = moduleOrKey
			} else {
				guard let k = try args.popFirst().map({ try String($0) }) else {
					throw Error.invalidArguments
				}
				module = moduleOrKey
				key = k
			}
			let defaultValue = args.popFirst()
			if let value = cache[module]?[key] {
				return value ?? defaultValue ?? PerlScalar()
			}
			let value: PerlScalar? = try Config.getModule(module).withUnsafeValue(key: key, body: decodeValue)
			if cache[module] != nil {
				cache[module]![key] = value
			} else {
				cache[module] = [key: value]
			}
			return value ?? defaultValue ?? PerlScalar()
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
			if Config.reload() {
				cache = [:]
				moduleCache = [:]
			}
		}

		// mympop & qm compatibility
		try! perl.pointee.eval("{ package MR::OnlineConf; use overload '%{}' => sub { return { cfg => { check_interval => 5 } } }, fallback => 1; }")
	}

	private static func decodeValue(_ value: Config.UnsafeValue) throws -> PerlScalar {
		switch value.format {
			case .text: return PerlScalar(value.data, containing: .characters)
			case .json: return try PerlSub.call("JSON::XS::decode_json", PerlScalar(value.data, containing: .bytes))
			case .cbor: return try PerlSub.call("CBOR::XS::decode_cbor", PerlScalar(value.data, containing: .bytes))
		}
	}

	enum Error : Swift.Error {
		case invalidArguments
	}
}
