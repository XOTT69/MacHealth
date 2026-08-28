import Foundation
import Combine
import CoreLocation
import CoreWLAN

final class MacDiagService: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var systemInfo = MacSystemInfo()
    @Published var battery = BatteryData()
    @Published var cpu = CPUData()
    @Published var gpu = GPUData()
    @Published var ram = RAMData()
    @Published var storage = StorageData()
    @Published var network = NetworkData()
    @Published var display = DisplayData()
    @Published var isLoading = false
    @Published var overallHealth: HealthLevel = .unknown
    @Published var lastUpdated: Date?
    
    private var timer: Timer?
    private var monitoringTick = 0
    private let locationManager = CLLocationManager()

    override init() {
        super.init()
        locationManager.delegate = self
        requestWiFiAccess()
    }
    
    func startMonitoring() {
        stopMonitoring()
        fetchAll()
        timer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            self?.fetchLiveData()
        }
    }
    
    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
    }

    /// SSID і BSSID на сучасних macOS захищені дозволом Location Services.
    /// Без нього CoreWLAN повертає лише частину параметрів мережі.
    func requestWiFiAccess() {
        guard CLLocationManager.locationServicesEnabled() else { return }
        if locationManager.authorizationStatus == .notDetermined {
            locationManager.requestWhenInUseAuthorization()
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        fetchNetwork()
    }
    
    func fetchAll() {
        isLoading = true
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.fetchSystemInfo()
            self?.fetchBattery()
            self?.fetchCPU()
            self?.fetchGPU()
            self?.fetchRAM()
            self?.fetchStorage()
            self?.fetchNetwork()
            self?.fetchDisplay()
            
            DispatchQueue.main.async {
                self?.calculateOverallHealth()
                self?.lastUpdated = Date()
                self?.isLoading = false
            }
        }
    }
    
    func fetchLiveData() {
        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self else { return }
            self.fetchCPU()
            self.fetchRAM()
            self.monitoringTick += 1
            // Батарея й Wi‑Fi оновлюються раз на 15 секунд, щоб панель
            // залишалася актуальною, але без важкого постійного опитування.
            if self.monitoringTick.isMultiple(of: 3) {
                self.fetchBattery()
                self.fetchNetwork()
            }
        }
    }
    
    // MARK: - System Info
    
    private func fetchSystemInfo() {
        let hw = Shell.systemProfiler("SPHardwareDataType")
        let model = Shell.grep(from: hw, pattern: "Model Name")
        let identifier = Shell.sysctl("hw.model")
        let serial = Shell.grep(from: hw, pattern: "Serial Number")
        let chip = Shell.grep(from: hw, pattern: "Chip").notEmpty ?? Shell.sysctl("machdep.cpu.brand_string")
        let osVer = Shell.run("/usr/bin/sw_vers", arguments: ["-productVersion"]).output
        let osBuild = Shell.run("/usr/bin/sw_vers", arguments: ["-buildVersion"]).output
        let uptime = formatUptime(Shell.run("/usr/bin/uptime").output)
        let memSize = Shell.grep(from: hw, pattern: "Memory")
        
        DispatchQueue.main.async { [weak self] in
            self?.systemInfo = MacSystemInfo(
                modelName: model.orDash,
                modelIdentifier: identifier.orDash,
                serialNumber: serial.orDash,
                osVersion: "macOS \(osVer) (\(osBuild))",
                chip: chip.orDash,
                uptime: uptime.orDash,
                memory: memSize.orDash
            )
        }
    }
    
    // MARK: - Battery
    
    private func fetchBattery() {
        let batteryResult = Shell.run("/usr/sbin/ioreg", arguments: ["-r", "-c", "AppleSmartBattery"])
        let raw = batteryResult.output

        guard batteryResult.succeeded, !raw.isEmpty else {
            DispatchQueue.main.async { [weak self] in
                self?.battery = BatteryData(isPresent: false, condition: "Батарея не виявлена")
            }
            return
        }
        
        let cycleCount = extractInt(from: raw, key: "CycleCount")
        // На Apple Silicon верхні MaxCapacity/CurrentCapacity часто містять
        // відсотки. Фактичні mAh лежать у вкладеному BatteryData словнику.
        let desCap = extractInt(from: raw, key: "DesignCapacity")
        let fullChargeCap = extractInt(from: raw, key: "FullChargeCapacity")
        let remainingCap = extractInt(from: raw, key: "RemainingCapacity")
        let reportedChargePercent = extractInt(from: raw, key: "CurrentCapacity")
        let maxCap = fullChargeCap > 0 ? fullChargeCap : extractInt(from: raw, key: "MaxCapacity")
        let curCap = remainingCap > 0 ? remainingCap : extractInt(from: raw, key: "CurrentCapacity")
        let isCharging = raw.contains("\"IsCharging\" = Yes")
        let tempRaw = extractInt(from: raw, key: "Temperature")
        let voltage = extractInt(from: raw, key: "Voltage")
        
        let healthAvailable = desCap > 0 && maxCap > 0
        let health = healthAvailable ? min(Double(maxCap) / Double(desCap) * 100, 100) : 0
        let hasRemainingCapacity = raw.contains("\"RemainingCapacity\"")
        let hasReportedCharge = raw.contains("\"CurrentCapacity\"")
        let derivedCharge = maxCap > 0 && hasRemainingCapacity ? Double(remainingCap) / Double(maxCap) * 100 : -1
        let chargeAvailable = derivedCharge >= 0 || hasReportedCharge
        let charge = derivedCharge >= 0 ? derivedCharge : Double(reportedChargePercent)
        let temp = Double(tempRaw) / 100.0
        
        let condition: String
        if !healthAvailable { condition = "Стан ємності недоступний" }
        else if health >= 80 { condition = "Нормальний" }
        else if health >= 60 { condition = "Зношений" }
        else { condition = "Потребує заміни" }
        
        let powerState = Shell.run("/usr/bin/pmset", arguments: ["-g", "batt"]).output
        let timeStr = extractTime(from: powerState)
        let isFullyCharged = powerState.localizedCaseInsensitiveContains("charged")
        
        DispatchQueue.main.async { [weak self] in
            self?.battery = BatteryData(
                isPresent: true,
                healthAvailable: healthAvailable,
                chargeAvailable: chargeAvailable,
                healthPercent: health,
                cycleCount: cycleCount,
                maxCapacity: maxCap,
                designCapacity: desCap,
                currentCharge: curCap,
                chargePercent: min(max(charge, 0), 100),
                isCharging: isCharging,
                temperature: temp,
                temperatureAvailable: tempRaw > 0,
                condition: condition,
                timeRemaining: timeStr.isEmpty ? (isCharging ? "Заряджається" : (isFullyCharged ? "Повністю заряджено" : "—")) : timeStr,
                voltage: Double(voltage) / 1000.0
            )
        }
    }
    
    // MARK: - CPU
    
    private func fetchCPU() {
        let name = Shell.sysctl("machdep.cpu.brand_string").notEmpty ?? "Apple Silicon"
        let cores = Int(Shell.sysctl("hw.ncpu")) ?? 0
        let perf = Int(Shell.sysctl("hw.perflevel0.logicalcpu")) ?? 0
        let eff = Int(Shell.sysctl("hw.perflevel1.logicalcpu")) ?? 0
        
        let cpuResult = Shell.run("/bin/ps", arguments: ["-A", "-o", "%cpu"])
        let cpuLines = cpuResult.output
        let totalUsage = cpuLines.components(separatedBy: .newlines)
            .dropFirst()
            .compactMap { Double($0.trimmingCharacters(in: .whitespaces)) }
            .reduce(0, +)
        let normalized = cores > 0 ? min(totalUsage / Double(cores), 100) : 0
        
        DispatchQueue.main.async { [weak self] in
            self?.cpu = CPUData(
                isAvailable: cpuResult.succeeded && cores > 0,
                name: name,
                cores: cores,
                perfCores: perf,
                effCores: eff,
                usage: normalized,
                temperature: 0
            )
        }
    }
    
    // MARK: - GPU
    
    private func fetchGPU() {
        let disp = Shell.systemProfiler("SPDisplaysDataType")
        let gpuName = Shell.grep(from: disp, pattern: "Chipset Model")
        let metal = Shell.grep(from: disp, pattern: "Metal")
        let coresStr = Shell.grep(from: disp, pattern: "Total Number of Cores")
        
        DispatchQueue.main.async { [weak self] in
            self?.gpu = GPUData(
                name: gpuName.isEmpty ? "Інтегрована" : gpuName,
                cores: Int(coresStr) ?? 0,
                metal: metal.isEmpty ? "Недоступно" : metal
            )
        }
    }
    
    // MARK: - RAM
    
    private func fetchRAM() {
        let totalBytes = Double(Shell.sysctl("hw.memsize")) ?? 0
        let totalGB = totalBytes / 1_073_741_824

        // memory_pressure — системна оцінка доступної пам'яті, що включає
        // reclaimable/purgeable сторінки. Не додаємо compressed pages до active
        // та wired: це подвійно завищує використання на сучасних macOS.
        let pressure = Shell.run("/usr/bin/memory_pressure", arguments: ["-Q"]).output
        let freePercent = extractMemoryFreePercent(from: pressure)
        let freeGB: Double
        let usedGB: Double
        var didReadMemory = false
        if freePercent >= 0 {
            freeGB = totalGB * Double(freePercent) / 100
            usedGB = max(totalGB - freeGB, 0)
            didReadMemory = true
        } else {
            let vmStat = Shell.run("/usr/bin/vm_stat").output
            let pageSize = parsePageSize(from: vmStat)
            var active: Double = 0, wired: Double = 0
            for line in vmStat.components(separatedBy: "\n") {
                if line.contains("Pages active") { active = parseVMPages(line) }
                else if line.contains("Pages wired") { wired = parseVMPages(line) }
            }
            usedGB = min((active + wired) * pageSize / 1_073_741_824, totalGB)
            freeGB = max(totalGB - usedGB, 0)
            didReadMemory = !vmStat.isEmpty
        }
        
        let memType = Shell.grep(from: Shell.systemProfiler("SPMemoryDataType"), pattern: "Type:")
        
        DispatchQueue.main.async { [weak self] in
            self?.ram = RAMData(
                isAvailable: totalGB > 0 && didReadMemory,
                totalGB: totalGB,
                usedGB: usedGB,
                freeGB: freeGB,
                type: memType.isEmpty ? "Unified Memory" : memType,
                pressure: totalGB > 0 ? (usedGB / totalGB) * 100 : 0
            )
        }
    }
    
    // MARK: - Storage
    
    private func fetchStorage() {
        let df = Shell.run("/bin/df", arguments: ["-kP", "/"]).output
        let parts = df.components(separatedBy: .newlines).last?
            .components(separatedBy: .whitespaces)
            .filter { !$0.isEmpty } ?? []
        
        var total: Double = 0, used: Double = 0, free: Double = 0
        if parts.count >= 4 {
            total = (Double(parts[1]) ?? 0) / 1_048_576
            used = (Double(parts[2]) ?? 0) / 1_048_576
            free = (Double(parts[3]) ?? 0) / 1_048_576
        }
        
        let storageProfile = Shell.systemProfiler("SPStorageDataType")
        let diskInfo = Shell.run("/usr/sbin/diskutil", arguments: ["info", "/"]).output
        let diskType = Shell.grep(from: storageProfile, pattern: "Medium Type")
        let fs = Shell.grep(from: diskInfo, pattern: "File System Personality")
        let smart = Shell.grep(from: Shell.run("/usr/sbin/diskutil", arguments: ["info", "disk0"]).output, pattern: "SMART Status")
        
        DispatchQueue.main.async { [weak self] in
            self?.storage = StorageData(
                isAvailable: total > 0,
                totalGB: total,
                usedGB: used,
                freeGB: free,
                type: diskType.orDash,
                fileSystem: fs.orDash,
                smartStatus: smart.isEmpty ? "Недоступно" : smart
            )
        }
    }
    
    // MARK: - Network
    
    private func fetchNetwork() {
        let wifi = CWWiFiClient.shared().interface()
        let interface = wifi?.interfaceName ?? Shell.defaultNetworkInterface().notEmpty ?? "en0"
        let ssid = wifi?.ssid()
        let signal = wifi.map { Int($0.rssiValue()) } ?? 0
        let channel = wifi?.wlanChannel()?.channelNumber ?? 0
        let linkSpeed = wifi.map { String(format: "%.0f Mbps", $0.transmitRate()) } ?? "—"
        let bssid = wifi?.bssid() ?? "—"

        let localIP = Shell.run("/usr/sbin/ipconfig", arguments: ["getifaddr", interface]).output
        let ifconfig = Shell.run("/sbin/ifconfig", arguments: [interface]).output
        let mac = ifconfig.components(separatedBy: .newlines)
            .first { $0.trimmingCharacters(in: .whitespaces).hasPrefix("ether ") }?
            .trimmingCharacters(in: .whitespaces)
            .split(separator: " ")
            .dropFirst()
            .first.map(String.init) ?? ""
        let wifiOn = wifi?.powerOn() ?? false
        let bt = Shell.grep(from: Shell.systemProfiler("SPBluetoothDataType"), pattern: "Bluetooth Core Spec")
        let accessMessage: String?
        if wifi != nil && ssid == nil {
            accessMessage = "Щоб показати назву мережі, дозвольте MacHealth доступ до геолокації в Системних параметрах."
        } else {
            accessMessage = nil
        }
        
        DispatchQueue.main.async { [weak self] in
            self?.network = NetworkData(
                wifiSSID: ssid ?? (wifiOn ? "Не визначено" : "Wi-Fi вимкнено"),
                wifiSignal: signal,
                wifiChannel: channel,
                wifiSpeed: linkSpeed,
                wifiBSSID: bssid,
                localIP: localIP.isEmpty ? "—" : localIP,
                externalIP: "—",
                macAddress: mac.orDash,
                isWifiOn: wifiOn,
                bluetoothVersion: bt.orDash,
                interfaceName: interface,
                wifiAccessMessage: accessMessage
            )
        }
    }
    
    // MARK: - Display
    
    private func fetchDisplay() {
        let disp = Shell.systemProfiler("SPDisplaysDataType")
        let res = Shell.grep(from: disp, pattern: "Resolution")
        let name = Shell.grep(from: disp, pattern: "Display Type")
        let retina = disp.contains("Retina")
        
        DispatchQueue.main.async { [weak self] in
            self?.display = DisplayData(
                name: name.isEmpty ? "Вбудований дисплей" : name,
                resolution: res.orDash,
                isRetina: retina
            )
        }
    }
    
    // MARK: - Overall Health
    
    private func calculateOverallHealth() {
        let levels = [battery.level, cpu.level, ram.level, storage.level].filter { $0 != .unknown }
        guard !levels.isEmpty else {
            overallHealth = .unknown
            return
        }
        if levels.contains(.critical) { overallHealth = .critical }
        else if levels.contains(.warning) { overallHealth = .warning }
        else if levels.contains(.good) { overallHealth = .good }
        else { overallHealth = .excellent }
    }
    
    // MARK: - Helpers
    
    private func extractInt(from text: String, key: String) -> Int {
        let pattern = "\"\(key)\"\\s*=\\s*(\\d+)"
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let range = Range(match.range(at: 1), in: text) else { return 0 }
        return Int(text[range]) ?? 0
    }
    
    private func parseVMPages(_ line: String) -> Double {
        let numStr = line.components(separatedBy: ":").last?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: ".", with: "")
            .filter { $0.isNumber } ?? "0"
        return Double(numStr) ?? 0
    }

    private func parsePageSize(from vmStat: String) -> Double {
        let pattern = "page size of\\s+(\\d+)\\s+bytes"
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: vmStat, range: NSRange(vmStat.startIndex..., in: vmStat)),
              let range = Range(match.range(at: 1), in: vmStat),
              let pageSize = Double(vmStat[range]) else { return 16_384 }
        return pageSize
    }

    private func extractMemoryFreePercent(from text: String) -> Int {
        let pattern = "System-wide memory free percentage:\\s*(\\d+)%"
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let range = Range(match.range(at: 1), in: text) else { return -1 }
        return Int(text[range]) ?? -1
    }

    private func extractTime(from text: String) -> String {
        let pattern = "\\b\\d{1,2}:\\d{2}\\b"
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let range = Range(match.range, in: text) else { return "" }
        return String(text[range])
    }

    private func formatUptime(_ text: String) -> String {
        guard let upRange = text.range(of: " up ") else { return text.orDash }
        let tail = text[upRange.upperBound...]
        return tail.split(separator: ",", maxSplits: 1).first
            .map { String($0).trimmingCharacters(in: .whitespaces) } ?? text.orDash
    }
}
