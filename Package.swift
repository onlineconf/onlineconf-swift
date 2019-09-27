// swift-tools-version:5.0
import PackageDescription

let perl = false
let benchmark = false

let package = Package(
	name: "OnlineConf",
	products: [
		.library(name: "OnlineConf", targets: ["OnlineConf"]),
		.executable(name: "onlineconf-get", targets: ["onlineconf-get"]),
	],
	targets: [
		.target(name: "CCKV"),
		.target(name: "OnlineConf", dependencies: ["CCKV"]),
		.target(name: "onlineconf-get", dependencies: ["OnlineConf"]),
		.testTarget(name: "OnlineConfTests", dependencies: ["OnlineConf"]),
	]
)

if perl {
	package.products.append(.library(name: "perlOnlineConf", type: .dynamic, targets: ["OnlineConfPerl"]))
	package.dependencies.append(.package(url: "https://github.com/my-mail-ru/swiftperl.git", from: "1.1.0"))
	package.targets.append(.target(name: "OnlineConfPerl", dependencies: ["OnlineConf", "Perl"]))
	package.targets.append(.testTarget(name: "OnlineConfPerlTests", dependencies: ["OnlineConfPerl"]))
}

if benchmark {
	package.targets.append(.target(name: "onlineconf-benchmark", dependencies: ["OnlineConf", "Benchmark"]))
	package.dependencies.append(.package(url: "https://github.com/my-mail-ru/swift-Benchmark.git", from: "0.3.1"))
}
