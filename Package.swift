import PackageDescription

let package = Package(
	name: "OnlineConf",
	targets: [
		Target(name: "CCKV"),
		Target(name: "OnlineConf", dependencies: [.Target(name: "CCKV")]),
    ]
)
