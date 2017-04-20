import PackageDescription

let benchmark = false

let package = Package(
	name: "OnlineConf",
	targets: [
		Target(name: "CCKV"),
		Target(name: "OnlineConf", dependencies: [.Target(name: "CCKV")]),
		Target(name: "OnlineConfPerl", dependencies: [.Target(name: "OnlineConf")]),
	],
	dependencies: [
		.Package(url: "https://github.com/my-mail-ru/swiftperl.git", versions: Version(0, 5, 0)..<Version(0, .max, .max)),
	]
)

products.append(Product(name: "/perl5/auto/MR/OnlineConf/OnlineConf", type: .Library(.Dynamic), modules: "OnlineConfPerl"))

if benchmark {
	package.targets.append(Target(name: "onlineconf-benchmark", dependencies: [.Target(name: "OnlineConf")]))
	package.dependencies.append(.Package(url: "https://github.com/my-mail-ru/swift-Benchmark.git", majorVersion: 0))
} else {
	package.exclude.append("Sources/onlineconf-benchmark")
}
