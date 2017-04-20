import OnlineConf
import Benchmark

let count = 1000000

timethis(count: count, title: "Config.withUnsafeValue()") {
	_ = Config.withUnsafeValue(key: "/my/interaction/mail/timezones") { _ in 10 }
}

timethis(count: count, title: "Config.get() -> String?") {
	_ = Config.get("/my/interaction/mail/timezones") as String?
}

timethis(count: count, title: "Config.get() -> Int?") {
	_ = Config.get("/my/core/comments/likes-limit") as Int?
}

timethis(count: count, title: "Config.get() -> Bool") {
	_ = Config.get("/my/core/comments/enable-eventproxy") as Bool
}

timethis(count: count, title: "Config.get() -> [String]? (text)") {
	_ = Config.get("/infrastructure/alertd") as [String]?
}

timethis(count: count, title: "Config.get() -> [String]? (json)") {
	_ = Config.get("/my/interaction/mail/timezones") as [String]?
}

timethis(count: count, title: "Config.getJSON()") {
	_ = Config.getJSON("/my/interaction/mail/timezones")
}
