import Foundation
import IOKit.ps

class MacDiagnosticService: ObservableObject {
    @Published var macInfo = MacInfo()
    @Published var batteryInfo = BatteryInfo()
    @Published var cpuInfo = CPUInfo()
    @Published var gpuInfo = GPUInfo()
    @Published var ramInfo = RAMInfo()
    @Published var storageInfo = StorageInfo()
    @Published var networkInfo = NetworkInfo()
    @Published var displayInfo = DisplayInfo()
    @Published var recommendations: [Recommendation] = []
    @Published var isLoading = false
    @Published var overallHealth: HealthStatus = .good
    
    func runFullDiagnostics() {
        isLoading = true
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.fetchMacInfo()
            self?.fetchBatteryInfo()
            self?.fetchCPUInfo()
            self?.fetchGPUInfo()
            self?.fetchRAMInfo()
            self?.fetchStorageInfo()
            self?.fetchNetworkInfo()
            self?.fetchDisplayInfo()
            
            DispatchQueue.main.async {
                self?.generateRecommendations()
                self?.calculateOverallHealth()
                self?.isLoading = false
            }
        }
    }
    
    // MARK: - Mac Info
    
    private func fetchMacInfo() {
        let hwModel = ShellExecutor.sysctl(key: "hw.model")
        let osVersion = ShellExecutor.execute("sw_vers -productVersion")
        let osBuild = ShellExecutor.execute("sw_vers -buildVersion")
        let serialNumber = ShellExecutor.execute("system_profiler SPHardwareDataType | grep 'Serial Number' | awk -F': ' '{print $2}'")
        let modelName = ShellExecutor.execute("system_profiler SPHardwareDataType | grep 'Model Name' | awk -F': ' '{print $2}'")
        let chip = ShellExecutor.execute("system_profiler SPHardwareDataType | grep 'Chip' | awk -F': ' '{print $2}'")
        let uptime = ShellExecutor.execute("uptime | awk -F'up ' '{print $2}' | awk -F',' '{print $1}'")
        
        DispatchQueue.main.async { [weak self] in
            self?.macInfo = MacInfo(
                modelName: modelName.isEmpty ? "Mac" : modelName,
                modelIdentifier: hwModel,
                serialNumber: serialNumber.isEmpty ? "Недоступно" : serialNumber,
                osVersion: "macOS \(osVersion) (\(osBuild))",
                chipInfo: chip.isEmpty ? ShellExecutor.sysctl(key: "machdep.cpu.brand_string") : chip,
                uptime: uptime
            )
        }
    }
    
    // MARK: - Battery Info
    
    private func fetchBatteryInfo() {
        let batteryData = ShellExecutor.execute("ioreg -r -c AppleSmartBattery")
        
        let cycleCount = extractValue(from: batteryData, key: "CycleCount") ?? "0"
        let maxCapacity = extractValue(from: batteryData, key: "MaxCapacity") ?? "100"
        let designCapacity = extractValue(from: batteryData, key: "DesignCapacity") ?? "100"
        let currentCapacity = extractValue(from: batteryData, key: "CurrentCapacity") ?? "0"
        let isCharging = batteryData.contains("\"IsCharging\" = Yes")
        let temperature = extractValue(from: batteryData, key: "Temperature") ?? "0"
        
        let maxCap = Double(maxCapacity) ?? 100
        let desCap = Double(designCapacity) ?? 100
        let healthPct = desCap > 0 ? (maxCap / desCap) * 100.0 : 100.0
        let tempCelsius = (Double(temperature) ?? 0) / 100.0
        
        let condition: String
        if healthPct >= 80 {
            condition = "Нормальний"
        } else if healthPct >= 60 {
            condition = "Зношений"
        } else {
            condition = "Потребує заміни"
        }
        
        let timeRemaining = ShellExecutor.execute("pmset -g batt | grep -o '[0-9]*:[0-9]*'")
        
        DispatchQueue.main.async { [weak self] in
            self?.batteryInfo = BatteryInfo(
                cycleCount: Int(cycleCount) ?? 0,
                maxCapacity: Int(maxCapacity) ?? 100,
                designCapacity: Int(designCapacity) ?? 100,
                healthPercentage: min(healthPct, 100.0),
                isCharging: isCharging,
                currentCharge: Int(currentCapacity) ?? 0,
                temperature: tempCelsius,
                condition: condition,
                timeRemaining: timeRemaining.isEmpty ? "Підключено до мережі" : timeRemaining
            )
        }
    }
    
    // MARK: - CPU Info
    
    private func fetchCPUInfo() {
        let cpuBrand = ShellExecutor.sysctl(key: "machdep.cpu.brand_string")
        let coreCount = ShellExecutor.sysctl(key: "hw.ncpu")
        let perfCores = ShellExecutor.sysctl(key: "hw.perflevel0.logicalcpu")
        let effCores = ShellExecutor.sysctl(key: "hw.perflevel1.logicalcpu")
        
        // CPU usage
        let cpuUsageStr = ShellExecutor.execute("ps -A -o %cpu | awk '{s+=$1} END {print s}'")
        let cpuUsage = Double(cpuUsageStr) ?? 0
        let cores = Double(coreCount) ?? 1
        let normalizedUsage = min(cpuUsage / cores, 100.0)
        
        // Temperature (якщо доступно)
        let tempStr = ShellExecutor.execute("sudo powermetrics --samplers smc -i 1 -n 1 2>/dev/null | grep 'CPU die temperature' | awk '{print $4}'")
        let temp = Double(tempStr) ?? 0
        
        DispatchQueue.main.async { [weak self] in
            self?.cpuInfo = CPUInfo(
                modelName: cpuBrand.isEmpty ? "Apple Silicon" : cpuBrand,
                coreCount: Int(coreCount) ?? 0,
                performanceCores: Int(perfCores) ?? 0,
                efficiencyCores: Int(effCores) ?? 0,
                currentUsage: normalizedUsage,
                temperature: temp
            )
        }
    }
    
    // MARK: - GPU Info
    
    private func fetchGPUInfo() {
        let gpuName = ShellExecutor.execute("system_profiler SPDisplaysDataType | grep 'Chipset Model' | awk -F': ' '{print $2}'")
        let metalSupport = ShellExecutor.execute("system_profiler SPDisplaysDataType | grep 'Metal' | awk -F': ' '{print $2}'")
        let gpuCores = ShellExecutor.execute("system_profiler SPDisplaysDataType | grep 'Total Number of Cores' | awk -F': ' '{print $2}'")
        
        DispatchQueue.main.async { [weak self] in
            self?.gpuInfo = GPUInfo(
                modelName: gpuName.isEmpty ? "Інтегрована" : gpuName,
                coreCount: Int(gpuCores) ?? 0,
                metalSupport: metalSupport.isEmpty ? "Підтримується" : metalSupport
            )
        }
    }
    
    // MARK: - RAM Info
    
    private func fetchRAMInfo() {
        let totalMem = ShellExecutor.sysctl(key: "hw.memsize")
        let totalBytes = Double(totalMem) ?? 0
        let totalGB = totalBytes / 1_073_741_824
        
        let vmStat = ShellExecutor.execute("vm_stat")
        let pageSize: Double = 16384 // Apple Silicon default
        
        var freePages: Double = 0
        var activePages: Double = 0
        var inactivePages: Double = 0
        var wiredPages: Double = 0
        var compressedPages: Double = 0
        
        for line in vmStat.components(separatedBy: "\n") {
            if line.contains("Pages free") {
                freePages = extractNumber(from: line)
            } else if line.contains("Pages active") {
                activePages = extractNumber(from: line)
            } else if line.contains("Pages inactive") {
                inactivePages = extractNumber(from: line)
            } else if line.contains("Pages wired") {
                wiredPages = extractNumber(from: line)
            } else if line.contains("Pages occupied by compressor") {
                compressedPages = extractNumber(from: line)
            }
        }
        
        let usedBytes = (activePages + wiredPages + compressedPages) * pageSize
        let usedGB = usedBytes / 1_073_741_824
        let freeGB = totalGB - usedGB
        let usagePct = totalGB > 0 ? (usedGB / totalGB) * 100 : 0
        
        let memType = ShellExecutor.execute("system_profiler SPMemoryDataType | grep 'Type' | head -1 | awk -F': ' '{print $2}'")
        
        DispatchQueue.main.async { [weak self] in
            self?.ramInfo = RAMInfo(
                totalGB: totalGB,
                usedGB: usedGB,
                freeGB: max(freeGB, 0),
                type: memType.isEmpty ? "Unified Memory" : memType,
                usagePercentage: usagePct
            )
        }
    }
    
    // MARK: - Storage Info
    
    private func fetchStorageInfo() {
        let dfOutput = ShellExecutor.execute("df -H / | tail -1")
        let parts = dfOutput.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
        
        var totalGB: Double = 0
        var usedGB: Double = 0
        var freeGB: Double = 0
        var usagePct: Double = 0
        
        if parts.count >= 5 {
            totalGB = parseSize(parts[1])
            usedGB = parseSize(parts[2])
            freeGB = parseSize(parts[3])
            usagePct = Double(parts[4].replacingOccurrences(of: "%", with: "")) ?? 0
        }
        
        let diskType = ShellExecutor.execute("system_profiler SPStorageDataType | grep 'Medium Type' | awk -F': ' '{print $2}'")
        let fileSystem = ShellExecutor.execute("diskutil info / | grep 'File System' | awk -F': ' '{print $2}'")
        let smartStatus = ShellExecutor.execute("diskutil info disk0 | grep 'SMART Status' | awk -F': ' '{print $2}'")
        
        DispatchQueue.main.async { [weak self] in
            self?.storageInfo = StorageInfo(
                totalGB: totalGB,
                usedGB: usedGB,
                freeGB: freeGB,
                type: diskType.isEmpty ? "SSD" : diskType,
                fileSystem: fileSystem.isEmpty ? "APFS" : fileSystem,
                usagePercentage: usagePct,
                smartStatus: smartStatus.isEmpty ? "Verified" : smartStatus
            )
        }
    }
    
    // MARK: - Network Info
    
    private func fetchNetworkInfo() {
        let wifiName = ShellExecutor.execute("networksetup -getairportnetwork en0 2>/dev/null | awk -F': ' '{print $2}'")
        let wifiMAC = ShellExecutor.execute("ifconfig en0 | grep 'ether' | awk '{print $2}'")
        let localIP = ShellExecutor.execute("ipconfig getifaddr en0 2>/dev/null")
        let btVersion = ShellExecutor.execute("system_profiler SPBluetoothDataType | grep 'Bluetooth Core Spec' | awk -F': ' '{print $2}'")
        let wifiEnabled = !ShellExecutor.execute("networksetup -getairportpower en0 | grep 'On'").isEmpty
        
        DispatchQueue.main.async { [weak self] in
            self?.networkInfo = NetworkInfo(
                wifiName: wifiName.isEmpty ? "Не підключено" : wifiName,
                wifiMAC: wifiMAC.isEmpty ? "—" : wifiMAC,
                localIP: localIP.isEmpty ? "—" : localIP,
                bluetoothVersion: btVersion.isEmpty ? "—" : btVersion,
                isWifiEnabled: wifiEnabled,
                isBluetoothEnabled: true
            )
        }
    }
    
    // MARK: - Display Info
    
    private func fetchDisplayInfo() {
        let displayName = ShellExecutor.execute("system_profiler SPDisplaysDataType | grep 'Display Type' | awk -F': ' '{print $2}'")
        let resolution = ShellExecutor.execute("system_profiler SPDisplaysDataType | grep 'Resolution' | head -1 | awk -F': ' '{print $2}'")
        let isRetina = resolution.contains("Retina") || ShellExecutor.execute("system_profiler SPDisplaysDataType").contains("Retina")
        
        DispatchQueue.main.async { [weak self] in
            self?.displayInfo = DisplayInfo(
                name: displayName.isEmpty ? "Вбудований дисплей" : displayName,
                resolution: resolution.isEmpty ? "—" : resolution,
                displayType: isRetina ? "Retina" : "Стандартний",
                size: "—"
            )
        }
    }
    
    // MARK: - Recommendations
    
    private func generateRecommendations() {
        var recs: [Recommendation] = []
        
        // Батарея
        if batteryInfo.healthPercentage < 80 {
            recs.append(Recommendation(
                category: "🔋 Батарея",
                status: batteryInfo.healthPercentage < 60 ? .critical : .warning,
                title: "Батарея зношена",
                description: "Здоров'я батареї: \(String(format: "%.0f", batteryInfo.healthPercentage))%. \(batteryInfo.healthPercentage < 60 ? "Рекомендуємо терміново замінити батарею." : "Рекомендуємо замінити найближчим часом.")",
                estimatedCost: "₴2000–4000"
            ))
        } else {
            recs.append(Recommendation(
                category: "🔋 Батарея",
                status: .good,
                title: "Батарея в нормі",
                description: "Здоров'я: \(String(format: "%.0f", batteryInfo.healthPercentage))%, \(batteryInfo.cycleCount) циклів. Заміна не потрібна.",
                estimatedCost: nil
            ))
        }
        
        // Батарея - цикли
        if batteryInfo.cycleCount > 800 {
            recs.append(Recommendation(
                category: "🔋 Батарея",
                status: .warning,
                title: "Велика кількість циклів заряду",
                description: "Кількість циклів: \(batteryInfo.cycleCount). Максимальна рекомендована кількість — 1000. Рекомендуємо планувати заміну.",
                estimatedCost: "₴2000–4000"
            ))
        }
        
        // SSD
        if storageInfo.usagePercentage > 90 {
            recs.append(Recommendation(
                category: "💾 Сховище",
                status: .critical,
                title: "Критично мало місця на диску",
                description: "Використано \(String(format: "%.0f", storageInfo.usagePercentage))% сховища. Звільніть місце або замініть на більший SSD.",
                estimatedCost: "₴3000–8000"
            ))
        } else if storageInfo.usagePercentage > 80 {
            recs.append(Recommendation(
                category: "💾 Сховище",
                status: .warning,
                title: "Мало вільного місця",
                description: "Використано \(String(format: "%.0f", storageInfo.usagePercentage))% сховища. Рекомендуємо очистити непотрібні файли.",
                estimatedCost: nil
            ))
        } else {
            recs.append(Recommendation(
                category: "💾 Сховище",
                status: .good,
                title: "Сховище в нормі",
                description: "Вільно \(String(format: "%.1f", storageInfo.freeGB)) ГБ. Проблем не виявлено.",
                estimatedCost: nil
            ))
        }
        
        // SMART
        if storageInfo.smartHealthStatus == .critical {
            recs.append(Recommendation(
                category: "💾 Сховище",
                status: .critical,
                title: "SMART-статус диска: проблема",
                description: "Диск може вийти з ладу. Терміново зробіть резервну копію та замініть диск!",
                estimatedCost: "₴3000–10000"
            ))
        }
        
        // RAM
        if ramInfo.usagePercentage > 90 {
            recs.append(Recommendation(
                category: "🧠 Оперативна пам'ять",
                status: .warning,
                title: "Високе використання RAM",
                description: "Використано \(String(format: "%.0f", ramInfo.usagePercentage))% оперативної пам'яті. Закрийте непотрібні програми або розгляньте оновлення Mac з більшою кількістю RAM.",
                estimatedCost: nil
            ))
        } else {
            recs.append(Recommendation(
                category: "🧠 Оперативна пам'ять",
                status: .good,
                title: "RAM в нормі",
                description: "Використано \(String(format: "%.1f", ramInfo.usedGB)) з \(String(format: "%.0f", ramInfo.totalGB)) ГБ. Проблем не виявлено.",
                estimatedCost: nil
            ))
        }
        
        // CPU
        if cpuInfo.temperature > 90 {
            recs.append(Recommendation(
                category: "💻 Процесор",
                status: .critical,
                title: "Перегрів процесора",
                description: "Температура CPU: \(String(format: "%.0f", cpuInfo.temperature))°C. Перевірте систему охолодження, можливо потрібна заміна термопасти.",
                estimatedCost: "₴500–1500"
            ))
        } else {
            recs.append(Recommendation(
                category: "💻 Процесор",
                status: .good,
                title: "Процесор працює нормально",
                description: "Навантаження: \(String(format: "%.0f", cpuInfo.currentUsage))%. Температура в нормі.",
                estimatedCost: nil
            ))
        }
        
        recommendations = recs
    }
    
    private func calculateOverallHealth() {
        let statuses = [
            batteryInfo.healthStatus,
            cpuInfo.usageStatus,
            ramInfo.usageStatus,
            storageInfo.usageStatus,
            storageInfo.smartHealthStatus
        ]
        
        if statuses.contains(.critical) {
            overallHealth = .critical
        } else if statuses.contains(.warning) {
            overallHealth = .warning
        } else {
            overallHealth = .good
        }
    }
    
    // MARK: - Helpers
    
    private func extractValue(from text: String, key: String) -> String? {
        let pattern = "\"\(key)\"\\s*=\\s*(.+)"
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) else {
            return nil
        }
        
        if let range = Range(match.range(at: 1), in: text) {
            let value = String(text[range]).trimmingCharacters(in: .whitespacesAndNewlines)
            return value.replacingOccurrences(of: ";", with: "").trimmingCharacters(in: .whitespaces)
        }
        return nil
    }
    
    private func extractNumber(from line: String) -> Double {
        let cleaned = line.components(separatedBy: ":").last ?? ""
        let numStr = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: ".", with: "")
            .filter { $0.isNumber }
        return Double(numStr) ?? 0
    }
    
    private func parseSize(_ str: String) -> Double {
        let cleaned = str.replacingOccurrences(of: ",", with: ".")
        if cleaned.hasSuffix("T") || cleaned.hasSuffix("Ti") {
            return (Double(cleaned.filter { $0.isNumber || $0 == "." }) ?? 0) * 1000
        } else if cleaned.hasSuffix("G") || cleaned.hasSuffix("Gi") {
            return Double(cleaned.filter { $0.isNumber || $0 == "." }) ?? 0
        } else if cleaned.hasSuffix("M") || cleaned.hasSuffix("Mi") {
            return (Double(cleaned.filter { $0.isNumber || $0 == "." }) ?? 0) / 1000
        }
        return Double(cleaned.filter { $0.isNumber || $0 == "." }) ?? 0
    }
}
