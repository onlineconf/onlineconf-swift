import PackageDescription

let package = Package(
	name: "OnlineConf",
	targets: [
		Target(name: "CCKV"),
		Target(name: "OnlineConf", dependencies: [.Target(name: "CCKV")]),
		Target(name: "OnlineConfPerl", dependencies: [.Target(name: "OnlineConf")]),
	],
	dependencies: [
		.Package(url: "https://github.com/my-mail-ru/swiftperl.git", versions: Version(0, 4, 0)..<Version(0, .max, .max)),
	]
)

products.append(Product(name: "XS/OnlineConf", type: .Library(.Dynamic), modules: "OnlineConfPerl"))
