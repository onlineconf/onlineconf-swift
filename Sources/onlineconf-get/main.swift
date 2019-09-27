import OnlineConf
#if os(macOS) || os(iOS) || os(watchOS) || os(tvOS)
import func Darwin.exit
#else
import func Glibc.exit
#endif

enum Format {
	case text
	case json
	case bool
}

var format = Format.text
var args = [String]()
for a in CommandLine.arguments.dropFirst() {
	switch a {
		case "-j":
			fallthrough
		case "--json":
			format = .json
		case "-b":
			fallthrough
		case "--bool":
			format = .bool
		case "-v":
			fallthrough
		case "--help":
			print("OVERVIEW: Read values from OnlineConf\n")
			print("USAGE: onlineconf-get [options] [module] key\n")
			print("OPTIONS:")
			print("  --bool, -b    Interpret value as boolean and exit with code 0 on true and 1 on false")
			print("  --json, -j    Decode JSON and print it as Swift structures")
			exit(0)
		default:
			args.append(a)
	}
}

let module: String
let key: String

switch args.count {
	case 1:
		module = "TREE"
		key = args[0]
	case 2:
		module = args[0]
		key = args[1]
	default:
		print("Invalid number of arguments")
		exit(1)
}

let config = try Config.getModule(module)
switch format {
	case .text:
		(config.get(key) as String?).map { print($0) }
	case .json:
		config.getJSON(key).map { print($0) }
	case .bool:
		exit(config.get(key) ?? false ? 0 : 1)
}
