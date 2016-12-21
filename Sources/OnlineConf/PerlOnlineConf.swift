
import Perl

@_cdecl("boot_OnlineConf")
func boot(_ p: UnsafeInterpreterPointer) {

	PerlSub(name: "MR::OnlineConf::get") {
	(_: String?, arg1: String?, arg2: String?, arg3: String?) -> PerlScalar in
		if arg1 == nil || (arg1 == nil && arg2 == nil) {
			return PerlScalar(arg3)
		}
		var module: String
		var key: String
		var defaultValue: String?
		if arg1!.characters.first == "/" {
			defaultValue = arg2
			key = arg1!
			module = "TREE"
		} else {
			module = arg1!
			key = arg2!
			defaultValue = arg3
		}

		if (module == "TREE") {
			guard let value: PerlScalar = Config.get(key)
			else { return PerlScalar(defaultValue) }
			return value
		}
		let config = try Config.configs[module] ?? Config(module: module)
		guard let value: PerlScalar = config.get(key)
		else { return PerlScalar(defaultValue) }
		return value
	}

	PerlSub(name: "MR::OnlineConf::reload") {
	(name: String, module: String) in
		if let config = Config.configs[module] {
			try config.reload()
		}
	}
}

