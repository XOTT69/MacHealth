import Foundation

struct PingResult: Identifiable {
    let id = UUID()
    var host: String = ""
    var time: Double = 0
    var ttl: Int = 0
    var isSuccess: Bool = true
    var timestamp: Date = Date()
}

struct SpeedTestResult {
    var downloadMbps: Double = 0
    var uploadMbps: Double = 0
    var ping: Double = 0
    var isRunning: Bool = false
    var progress: Double = 0
    var status: String = ""
}

struct LocalDevice: Identifiable {
    let id = UUID()
    var ip: String = ""
    var mac: String = ""
    var hostname: String = ""
    var isOnline: Bool = true
}

struct HardwareTestResult: Identifiable {
    let id = UUID()
    var testName: String = ""
    var result: String = ""
    var value: Double = 0
    var unit: String = ""
    var level: HealthLevel = .unknown
    var timestamp: Date = Date()
}
