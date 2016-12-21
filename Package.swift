import PackageDescription

let package = Package(
	name: "OnlineConf",
	targets: [
		Target(name: "CCKV"),
		Target(name: "OnlineConf", dependencies: [.Target(name: "CCKV")]),
	],
		dependencies: [
		.Package(url: "https://github.com/my-mail-ru/swiftperl.git",
			majorVersion: 0),
		]
)

products.append(Product(name: "OnlineConf", type: .Library(.Dynamic), modules: "OnlineConf"))
