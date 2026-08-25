import Foundation
import Combine

class NetworkService: ObservableObject {
    @Published var pingResults: [PingResult] = []
    @Published var speedTest = SpeedTestResult()
    @Published var localDevices: [LocalDevice] = []
    @Published var isPinging = false
    @Published var isScanning = false
    
    // MARK: - Ping
    
    func ping(host: String, count: Int = 5) {
        let normalizedHost = host.trimmingCharacters(in: .whitespacesAndNewlines)
        guard Self.isValidHost(normalizedHost) else {
            pingResults = [PingResult(host: normalizedHost, time: -1, ttl: 0, isSuccess: false)]
            return
        }

        isPinging = true
        pingResults = []
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            for i in 0..<count {
                let output = Shell.run("ping -c 1 -t 5 \(normalizedHost) 2>/dev/null")
                
                var result = PingResult(host: normalizedHost)
                
                if output.contains("time=") {
                    // Парсимо час відповіді
                    if let timeRange = output.range(of: "time=") {
                        let afterTime = String(output[timeRange.upperBound...])
                        let timeVal = afterTime.components(separatedBy: " ").first ?? "0"
                        result.time = Double(timeVal) ?? 0
                    }
                    if let ttlRange = output.range(of: "ttl=") {
                        let afterTTL = String(output[ttlRange.upperBound...])
                        let ttlVal = afterTTL.components(separatedBy: " ").first ?? "0"
                        result.ttl = Int(ttlVal) ?? 0
                    }
                    result.isSuccess = true
                } else {
                    result.isSuccess = false
                    result.time = -1
                }
                
                DispatchQueue.main.async {
                    self?.pingResults.append(result)
                }
                
                if i < count - 1 {
                    Thread.sleep(forTimeInterval: 0.5)
                }
            }
            
            DispatchQueue.main.async {
                self?.isPinging = false
            }
        }
    }
    
    // MARK: - Speed Test
    
    func runSpeedTest() {
        speedTest = SpeedTestResult(isRunning: true, status: "Вимірювання ping...")
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            // Ping
            let pingOutput = Shell.run("ping -c 3 8.8.8.8 2>/dev/null | tail -1")
            var avgPing: Double = 0
            if pingOutput.contains("/") {
                let parts = pingOutput.components(separatedBy: "/")
                if parts.count >= 5 {
                    avgPing = Double(parts[4]) ?? 0
                }
            }
            
            DispatchQueue.main.async {
                self?.speedTest.ping = avgPing
                self?.speedTest.progress = 0.2
                self?.speedTest.status = "Вимірювання завантаження..."
            }
            
            // Download speed - завантажуємо тестовий файл
            let rawSpeed = Shell.run("curl -L --max-time 30 -s -o /dev/null -w '%{speed_download}' 'https://speed.cloudflare.com/__down?bytes=10000000' 2>/dev/null")
            let downloadMbps = (Double(rawSpeed) ?? 0) * 8 / 1_000_000
            
            DispatchQueue.main.async {
                self?.speedTest.downloadMbps = downloadMbps
                self?.speedTest.progress = 0.7
                self?.speedTest.status = "Завершення тесту..."
            }
            
            DispatchQueue.main.async {
                // Не показуємо вигадану "оцінку" upload: для неї потрібен сервер,
                // який приймає тестові дані та не спотворює вимірювання.
                self?.speedTest.uploadMbps = 0
                self?.speedTest.progress = 1.0
                self?.speedTest.status = "Завершено"
                self?.speedTest.isRunning = false
            }
        }
    }
    
    // MARK: - Local Network Scan
    
    func scanLocalNetwork() {
        isScanning = true
        localDevices = []
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            // Отримуємо підмережу
            let interface = Shell.defaultNetworkInterface().notEmpty ?? "en0"
            let localIP = Shell.run("ipconfig getifaddr \(interface) 2>/dev/null")
            guard !localIP.isEmpty else {
                DispatchQueue.main.async {
                    self?.isScanning = false
                }
                return
            }
            
            let subnet = localIP.components(separatedBy: ".").prefix(3).joined(separator: ".")
            
            // Заповнюємо ARP-кеш короткими паралельними ping по підмережі.
            // subnet отримується з локальної IPv4-адреси, тому не містить введення користувача.
            let _ = Shell.run("seq 1 254 | xargs -P 24 -I{} ping -c 1 -W 100 \(subnet).{} >/dev/null 2>&1")
            
            let arpOutput = Shell.run("arp -a 2>/dev/null")
            var devices: [LocalDevice] = []
            
            for line in arpOutput.components(separatedBy: "\n") {
                guard line.contains("(") && line.contains(")") else { continue }
                
                var device = LocalDevice()
                
                // Parse IP
                if let start = line.range(of: "("), let end = line.range(of: ")") {
                    device.ip = String(line[start.upperBound..<end.lowerBound])
                }
                
                // Parse MAC
                let parts = line.components(separatedBy: " ")
                for (i, part) in parts.enumerated() {
                    if part == "at" && i + 1 < parts.count {
                        let mac = parts[i + 1]
                        if mac.contains(":") && mac != "(incomplete)" {
                            device.mac = mac
                        }
                    }
                }
                
                // Parse hostname
                if let firstParen = line.firstIndex(of: "(") {
                    device.hostname = String(line[line.startIndex..<firstParen]).trimmingCharacters(in: .whitespaces)
                }
                
                if !device.ip.isEmpty && device.mac != "—" && !device.mac.isEmpty {
                    device.isOnline = true
                    devices.append(device)
                }
            }
            
            DispatchQueue.main.async {
                self?.localDevices = devices
                self?.isScanning = false
            }
        }
    }
    
    // MARK: - Get External IP
    
    func fetchExternalIP(completion: @escaping (String) -> Void) {
        DispatchQueue.global(qos: .utility).async {
            let ip = Shell.run("curl -s ifconfig.me 2>/dev/null")
            DispatchQueue.main.async {
                completion(ip.orDash)
            }
        }
    }

    private static func isValidHost(_ value: String) -> Bool {
        guard !value.isEmpty, value.count <= 253 else { return false }
        return value.unicodeScalars.allSatisfy {
            CharacterSet.alphanumerics.contains($0) || $0 == "." || $0 == "-" || $0 == ":"
        }
    }
}
