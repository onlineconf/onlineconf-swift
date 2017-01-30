
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

	static var instance = OnlineConfPerl()
	static var cache = [String: [String: PerlScalar?]]()

	static func initialize(perl: UnsafeInterpreterPointer = UnsafeInterpreter.current) {
		createPerlMethod("instance") {
			(_: String) -> OnlineConfPerl in
			return instance
		}

		createPerlMethod("reload") {
			(_: PerlScalar, module: String, opts: [String: Bool]) in
			guard let config = Config.getModule(ifLoaded: module) else { return }
			if opts["force"] ?? false {
				try config.forceReload()
				cache[module] = nil
			} else if config.reload() {
				cache[module] = nil
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
			let value: PerlScalar? = try Config.getModule(module).withUnsafeValue(key: key) { value in
				switch value.format {
					case .text: return PerlScalar(value.data, containing: .characters)
					case .json: return try PerlSub.call("JSON::XS::decode_json", PerlScalar(value.data, containing: .bytes))
					case .cbor: return try PerlSub.call("CBOR::XS::decode_cbor", PerlScalar(value.data, containing: .bytes))
				}
			}
			if cache[module] != nil {
				cache[module]![key] = value
			} else {
				cache[module] = [key: value]
			}
			return value ?? defaultValue ?? PerlScalar()
		}

	}

	enum Error : Swift.Error {
		case invalidArguments
	}
}
