import PackageDescription

let package = Package(
	name: "OnlineConf",
	targets: [
		Target(name: "CCKV"),
		Target(name: "OnlineConf", dependencies: [.Target(name: "CCKV")]),
		Target(name: "OnlineConfPerl", dependencies: [.Target(name: "OnlineConf")]),
	],
		dependencies: [
		.Package(url: "https://github.com/my-mail-ru/swiftperl.git",
			majorVersion: 0),
		]
)

products.append(Product(name: "OnlineConf", type: .Library(.Dynamic), modules: "OnlineConfPerl"))
