
import OnlineConf
import Perl

@_cdecl("boot_OnlineConf")
public func boot(_ p: UnsafeInterpreterPointer) {
	try! p.pointee.eval("use CBOR::XS; use JSON::XS;")
	var cashValue = [String: [String:PerlScalar]]()
	PerlSub(name: "MR::OnlineConf::get") {
	(_: String, arg1: String, arg2: PerlScalar, arg3: PerlScalar) -> PerlScalar in
		var module: String
		var key: String
		var defaultValue: PerlScalar
		if arg1.characters.first == "/" {
			defaultValue = arg2
			key = arg1
			module = "TREE"
		} else {
			module = arg1
			if arg2.defined { key = try String(arg2) }
			else { return arg3 }
			defaultValue = arg3
		}
		if let cashValue = cashValue[module]?[key] {
			return (cashValue.defined ? cashValue : defaultValue)
		}
		let config = try Config.getModule(module)
		return try config!.withUnsafeRawBufferPointer(key: key) {
			var val = defaultValue
			if $0 != nil {
				let rawValue = $0!.0
				let type = $0!.1
				val = PerlScalar(rawValue, containing: type == "c" ? .bytes : .characters)
				if type == "j" {
					val = try p.pointee.call(sub: "JSON::XS::decode_json", args: [.some(val)])
				}
				else if type == "c" {
					val = try p.pointee.call(sub: "CBOR::XS::decode_cbor", args: [.some(val)])
				}
				if var hash = cashValue[module]{
					hash[key] = val
					cashValue[module] = hash
				}
				else {
					cashValue[module] = [key:val]
				}
			}
			return val
		}
	}

	PerlSub(name: "MR::OnlineConf::reload") {
	(name: String, module: String) in
		try Config.getModule(module, isCreate: false)?.reload()
		cashValue[module] = nil
	}
}

