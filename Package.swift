// swift-tools-version:5.0
import PackageDescription

let benchmark = false

let package = Package(
	name: "OnlineConf",
	products: [
		.library(name: "OnlineConf", targets: ["OnlineConf"]),
		.library(name: "perlOnlineConf", type: .dynamic, targets: ["OnlineConfPerl"]),
		.executable(name: "onlineconf-get", targets: ["onlineconf-get"]),
	],
	dependencies: [
		.package(url: "https://github.com/my-mail-ru/swiftperl.git", from: "1.1.0"),
	],
	targets: [
		.target(name: "CCKV"),
		.target(name: "OnlineConf", dependencies: ["CCKV"]),
		.target(name: "OnlineConfPerl", dependencies: ["OnlineConf", "Perl"]),
		.target(name: "onlineconf-get", dependencies: ["OnlineConf"]),
		.testTarget(name: "OnlineConfTests", dependencies: ["OnlineConf"]),
		.testTarget(name: "OnlineConfPerlTests", dependencies: ["OnlineConfPerl"]),
	]
)

if benchmark {
	package.targets.append(.target(name: "onlineconf-benchmark", dependencies: ["OnlineConf", "Benchmark"]))
	package.dependencies.append(.package(url: "https://github.com/my-mail-ru/swift-Benchmark.git", from: "0.3.1"))
}
