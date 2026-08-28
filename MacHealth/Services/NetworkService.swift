import Foundation
import Combine

final class NetworkService: ObservableObject {
    @Published var pingResults: [PingResult] = []
    @Published var speedTest = SpeedTestResult()
    @Published var localDevices: [LocalDevice] = []
    @Published var isPinging = false
    @Published var isScanning = false

    func ping(host: String, count: Int = 5) {
        let normalizedHost = host.trimmingCharacters(in: .whitespacesAndNewlines)
        guard Self.isValidHost(normalizedHost) else {
            pingResults = [PingResult(host: normalizedHost, time: -1, ttl: 0, isSuccess: false)]
            return
        }

        isPinging = true
        pingResults = []
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            var results: [PingResult] = []
            for _ in 0..<max(1, min(count, 10)) {
                let result = Shell.run("/sbin/ping", arguments: ["-c", "1", "-W", "1000", normalizedHost], timeout: 3)
                results.append(Self.parsePing(result.output, host: normalizedHost, succeeded: result.succeeded))
            }
            DispatchQueue.main.async {
                self?.pingResults = results
                self?.isPinging = false
            }
        }
    }

    /// Вимірює лише download і ping. Upload не підставляється, бо для нього потрібен контрольований сервер.
    func runSpeedTest() {
        speedTest = SpeedTestResult(isRunning: true, status: "Вимірювання затримки…")
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let ping = Shell.run("/sbin/ping", arguments: ["-c", "3", "-W", "1000", "1.1.1.1"], timeout: 10)
            let averagePing = Self.averagePing(from: ping.output)
            DispatchQueue.main.async {
                self?.speedTest.ping = averagePing
                self?.speedTest.progress = 0.25
                self?.speedTest.status = "Вимірювання завантаження (10 МБ)…"
            }

            let download = Shell.run(
                "/usr/bin/curl",
                arguments: ["-L", "--fail", "--silent", "--show-error", "--max-time", "30", "-o", "/dev/null", "-w", "%{speed_download}", "https://speed.cloudflare.com/__down?bytes=10000000"],
                timeout: 35
            )
            let downloadMbps = download.succeeded ? (Double(download.output) ?? 0) * 8 / 1_000_000 : 0
            DispatchQueue.main.async {
                self?.speedTest.downloadMbps = downloadMbps
                self?.speedTest.uploadMbps = 0
                self?.speedTest.progress = 1
                self?.speedTest.status = download.succeeded ? "Завершено" : "Не вдалося виміряти download"
                self?.speedTest.isRunning = false
            }
        }
    }

    /// Лише локальний ARP-огляд поточної /24 IPv4 мережі; не сканує порти та не виходить за межі LAN.
    func scanLocalNetwork() {
        isScanning = true
        localDevices = []
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let interface = Shell.defaultNetworkInterface().notEmpty ?? "en0"
            let ipResult = Shell.run("/usr/sbin/ipconfig", arguments: ["getifaddr", interface])
            let localIP = ipResult.succeeded ? ipResult.output : ""
            guard let subnet = Self.subnetPrefix(from: localIP) else {
                DispatchQueue.main.async { self?.isScanning = false }
                return
            }

            let queue = OperationQueue()
            queue.maxConcurrentOperationCount = 24
            for hostNumber in 1...254 {
                let host = "\(subnet).\(hostNumber)"
                queue.addOperation {
                    _ = Shell.run("/sbin/ping", arguments: ["-c", "1", "-W", "100", host], timeout: 2)
                }
            }
            queue.waitUntilAllOperationsAreFinished()
            let arp = Shell.run("/usr/sbin/arp", arguments: ["-a"]).output
            let devices = Self.parseARP(arp)
            DispatchQueue.main.async {
                self?.localDevices = devices
                self?.isScanning = false
            }
        }
    }

    func fetchExternalIP(completion: @escaping (String) -> Void) {
        DispatchQueue.global(qos: .utility).async {
            let result = Shell.run("/usr/bin/curl", arguments: ["--fail", "--silent", "--max-time", "8", "https://api.ipify.org"], timeout: 10)
            let ip = result.succeeded && Self.isValidIPAddress(result.output) ? result.output : "—"
            DispatchQueue.main.async { completion(ip) }
        }
    }

    private static func parsePing(_ output: String, host: String, succeeded: Bool) -> PingResult {
        guard succeeded,
              let time = firstMatch("time[=<]([0-9.]+)", in: output).flatMap(Double.init) else {
            return PingResult(host: host, time: -1, ttl: 0, isSuccess: false)
        }
        let ttl = firstMatch("ttl=(\\d+)", in: output).flatMap(Int.init) ?? 0
        return PingResult(host: host, time: time, ttl: ttl, isSuccess: true)
    }

    private static func averagePing(from output: String) -> Double {
        let summary = output.components(separatedBy: .newlines).last { $0.contains("min/avg/max") } ?? ""
        let values = summary.split(separator: "=").last?.split(separator: "/") ?? []
        return values.count >= 2 ? Double(values[1]) ?? 0 : 0
    }

    private static func parseARP(_ text: String) -> [LocalDevice] {
        var seen = Set<String>()
        return text.components(separatedBy: .newlines).compactMap { line in
            guard let start = line.firstIndex(of: "("), let end = line.firstIndex(of: ")") else { return nil }
            let ip = String(line[line.index(after: start)..<end])
            guard isValidIPv4(ip), let atRange = line.range(of: " at ") else { return nil }
            let mac = line[atRange.upperBound...].split(separator: " ").first.map(String.init) ?? ""
            guard mac.contains(":"), mac != "(incomplete)", seen.insert(ip).inserted else { return nil }
            let hostname = String(line[..<start]).trimmingCharacters(in: .whitespaces)
            return LocalDevice(ip: ip, mac: mac, hostname: hostname, isOnline: true)
        }
        .sorted { $0.ip.localizedStandardCompare($1.ip) == .orderedAscending }
    }

    private static func subnetPrefix(from ip: String) -> String? {
        guard isValidIPv4(ip) else { return nil }
        return ip.split(separator: ".").prefix(3).joined(separator: ".")
    }

    private static func firstMatch(_ pattern: String, in text: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let range = Range(match.range(at: 1), in: text) else { return nil }
        return String(text[range])
    }

    private static func isValidHost(_ value: String) -> Bool {
        guard !value.isEmpty, value.count <= 253 else { return false }
        return value.unicodeScalars.allSatisfy {
            CharacterSet.alphanumerics.contains($0) || $0 == "." || $0 == "-" || $0 == ":"
        }
    }

    private static func isValidIPAddress(_ value: String) -> Bool {
        isValidIPv4(value) || value.contains(":")
    }

    private static func isValidIPv4(_ value: String) -> Bool {
        let octets = value.split(separator: ".", omittingEmptySubsequences: false)
        return octets.count == 4 && octets.allSatisfy { UInt8($0) != nil }
    }
}
