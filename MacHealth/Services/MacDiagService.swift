import Foundation
import Combine

class MacDiagService: ObservableObject {
    @Published var systemInfo = MacSystemInfo()
    @Published var battery = BatteryData()
    @Published var cpu = CPUData()
    @Published var gpu = GPUData()
    @Published var ram = RAMData()
    @Published var storage = StorageData()
    @Published var network = NetworkData()
    @Published var display = DisplayData()
    @Published var isLoading = false
    @Published var overallHealth: HealthLevel = .excellent
    
    private var timer: Timer?
    
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
                self?.isLoading = false
            }
        }
    }
    
    func fetchLiveData() {
        DispatchQueue.global(qos: .utility).async { [weak self] in
            self?.fetchCPU()
            self?.fetchRAM()
        }
    }
    
    // MARK: - System Info
    
    private func fetchSystemInfo() {
        let hw = Shell.systemProfiler("SPHardwareDataType")
        let model = Shell.grep(from: hw, pattern: "Model Name")
        let identifier = Shell.sysctl("hw.model")
        let serial = Shell.grep(from: hw, pattern: "Serial Number")
        let chip = Shell.grep(from: hw, pattern: "Chip").notEmpty ?? Shell.sysctl("machdep.cpu.brand_string")
        let osVer = Shell.run("sw_vers -productVersion")
        let osBuild = Shell.run("sw_vers -buildVersion")
        let uptime = Shell.run("uptime | sed 's/.*up //' | sed 's/,.*//'")
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
        let raw = Shell.run("ioreg -r -c AppleSmartBattery")

        guard !raw.isEmpty else {
            DispatchQueue.main.async { [weak self] in
                self?.battery = BatteryData(isPresent: false, condition: "Батарея не виявлена")
            }
            return
        }
        
        let cycleCount = extractInt(from: raw, key: "CycleCount")
        let maxCap = extractInt(from: raw, key: "MaxCapacity")
        let desCap = extractInt(from: raw, key: "DesignCapacity")
        let curCap = extractInt(from: raw, key: "CurrentCapacity")
        let isCharging = raw.contains("\"IsCharging\" = Yes")
        let tempRaw = extractInt(from: raw, key: "Temperature")
        let voltage = extractInt(from: raw, key: "Voltage")
        
        let health = desCap > 0 ? min(Double(maxCap) / Double(desCap) * 100, 100) : 100
        let temp = Double(tempRaw) / 100.0
        
        let condition: String
        if health >= 80 { condition = "Нормальний" }
        else if health >= 60 { condition = "Зношений" }
        else { condition = "Потребує заміни" }
        
        let timeStr = Shell.run("pmset -g batt | grep -o '[0-9]*:[0-9]*'")
        
        DispatchQueue.main.async { [weak self] in
            self?.battery = BatteryData(
                isPresent: true,
                healthPercent: health,
                cycleCount: cycleCount,
                maxCapacity: maxCap,
                designCapacity: desCap,
                currentCharge: curCap,
                isCharging: isCharging,
                temperature: temp,
                condition: condition,
                timeRemaining: timeStr.isEmpty ? (isCharging ? "Заряджається" : "—") : timeStr,
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
        
        let usageStr = Shell.run("ps -A -o %cpu | awk '{s+=$1} END {print s}'")
        let totalUsage = Double(usageStr) ?? 0
        let normalized = cores > 0 ? min(totalUsage / Double(cores), 100) : 0
        
        DispatchQueue.main.async { [weak self] in
            self?.cpu = CPUData(
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
                metal: metal.isEmpty ? "Підтримується" : metal
            )
        }
    }
    
    // MARK: - RAM
    
    private func fetchRAM() {
        let totalBytes = Double(Shell.sysctl("hw.memsize")) ?? 0
        let totalGB = totalBytes / 1_073_741_824
        
        let vmStat = Shell.run("vm_stat")
        let pageSize = parsePageSize(from: vmStat)
        
        var active: Double = 0, wired: Double = 0, compressed: Double = 0
        for line in vmStat.components(separatedBy: "\n") {
            if line.contains("Pages active") { active = parseVMPages(line) }
            else if line.contains("Pages wired") { wired = parseVMPages(line) }
            else if line.contains("Pages occupied by compressor") { compressed = parseVMPages(line) }
        }
        
        let usedGB = (active + wired + compressed) * pageSize / 1_073_741_824
        let freeGB = max(totalGB - usedGB, 0)
        
        let memType = Shell.run("system_profiler SPMemoryDataType 2>/dev/null | grep 'Type:' | head -1 | awk -F': ' '{print $2}'")
        
        DispatchQueue.main.async { [weak self] in
            self?.ram = RAMData(
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
        let df = Shell.run("df -g / | tail -1")
        let parts = df.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
        
        var total: Double = 0, used: Double = 0, free: Double = 0
        if parts.count >= 4 {
            total = Double(parts[1]) ?? 0
            used = Double(parts[2]) ?? 0
            free = Double(parts[3]) ?? 0
        }
        
        let diskType = Shell.run("system_profiler SPStorageDataType 2>/dev/null | grep 'Medium Type' | awk -F': ' '{print $2}'")
        let fs = Shell.run("diskutil info / 2>/dev/null | grep 'File System' | awk -F': ' '{print $2}'")
        let smart = Shell.run("diskutil info disk0 2>/dev/null | grep 'SMART Status' | awk -F': ' '{print $2}'")
        
        DispatchQueue.main.async { [weak self] in
            self?.storage = StorageData(
                totalGB: total,
                usedGB: used,
                freeGB: free,
                type: diskType.isEmpty ? "SSD" : diskType,
                fileSystem: fs.isEmpty ? "APFS" : fs,
                smartStatus: smart.isEmpty ? "Verified" : smart
            )
        }
    }
    
    // MARK: - Network (Fixed Wi-Fi!)
    
    private func fetchNetwork() {
        let interface = Shell.defaultNetworkInterface().notEmpty ?? "en0"

        // airport може бути відсутнім у нових версіях macOS, тому є кілька fallback-ів.
        var ssid = Shell.run("/System/Library/PrivateFrameworks/Apple80211.framework/Versions/Current/Resources/airport -I 2>/dev/null | grep ' SSID' | awk -F': ' '{print $2}'")
        if ssid.isEmpty {
            ssid = Shell.run("networksetup -getairportnetwork \(interface) 2>/dev/null | awk -F': ' '{print $2}'")
        }
        if ssid.isEmpty {
            ssid = Shell.run("ipconfig getsummary \(interface) 2>/dev/null | grep '  SSID' | awk -F': ' '{print $2}'")
        }
        
        let signal = Shell.run("/System/Library/PrivateFrameworks/Apple80211.framework/Versions/Current/Resources/airport -I 2>/dev/null | grep 'agrCtlRSSI' | awk -F': ' '{print $2}'")
        let channel = Shell.run("/System/Library/PrivateFrameworks/Apple80211.framework/Versions/Current/Resources/airport -I 2>/dev/null | grep ' channel' | awk -F': ' '{print $2}'")
        let linkSpeed = Shell.run("/System/Library/PrivateFrameworks/Apple80211.framework/Versions/Current/Resources/airport -I 2>/dev/null | grep 'lastTxRate' | awk -F': ' '{print $2}'")
        
        let localIP = Shell.run("ipconfig getifaddr \(interface) 2>/dev/null")
        let mac = Shell.run("ifconfig \(interface) 2>/dev/null | grep 'ether' | awk '{print $2}'")
        let wifiOn = !Shell.run("networksetup -getairportpower \(interface) 2>/dev/null | grep 'On'").isEmpty
        let bt = Shell.run("system_profiler SPBluetoothDataType 2>/dev/null | grep 'Bluetooth Core Spec' | awk -F': ' '{print $2}'")
        
        DispatchQueue.main.async { [weak self] in
            self?.network = NetworkData(
                wifiSSID: ssid.isEmpty ? "Не визначено" : ssid,
                wifiSignal: Int(signal) ?? 0,
                wifiChannel: Int(channel.components(separatedBy: ",").first ?? "") ?? 0,
                wifiSpeed: linkSpeed.isEmpty ? "—" : "\(linkSpeed) Mbps",
                localIP: localIP.isEmpty ? "—" : localIP,
                externalIP: "—",
                macAddress: mac.orDash,
                isWifiOn: wifiOn,
                bluetoothVersion: bt.orDash,
                interfaceName: interface
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
        let levels = [battery.level, cpu.level, ram.level, storage.level]
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
}
