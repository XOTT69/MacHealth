import Foundation

struct MacSystemInfo {
    var modelName: String = "—"
    var modelIdentifier: String = "—"
    var serialNumber: String = "—"
    var osVersion: String = "—"
    var chip: String = "—"
    var uptime: String = "—"
    var memory: String = "—"
}

struct BatteryData {
    var healthPercent: Double = 100
    var cycleCount: Int = 0
    var maxCapacity: Int = 0
    var designCapacity: Int = 0
    var currentCharge: Int = 0
    var isCharging: Bool = false
    var temperature: Double = 0
    var condition: String = "Нормальний"
    var timeRemaining: String = "—"
    var voltage: Double = 0
    
    var level: HealthLevel {
        if healthPercent >= 85 { return .excellent }
        else if healthPercent >= 70 { return .good }
        else if healthPercent >= 50 { return .warning }
        else { return .critical }
    }
}

struct CPUData {
    var name: String = "—"
    var cores: Int = 0
    var perfCores: Int = 0
    var effCores: Int = 0
    var usage: Double = 0
    var temperature: Double = 0
    
    var level: HealthLevel {
        if usage < 60 { return .excellent }
        else if usage < 80 { return .good }
        else if usage < 95 { return .warning }
        else { return .critical }
    }
}

struct GPUData {
    var name: String = "—"
    var cores: Int = 0
    var metal: String = "—"
}

struct RAMData {
    var totalGB: Double = 0
    var usedGB: Double = 0
    var freeGB: Double = 0
    var type: String = "—"
    var pressure: Double = 0
    
    var usagePercent: Double {
        totalGB > 0 ? (usedGB / totalGB) * 100 : 0
    }
    
    var level: HealthLevel {
        if usagePercent < 60 { return .excellent }
        else if usagePercent < 80 { return .good }
        else if usagePercent < 95 { return .warning }
        else { return .critical }
    }
}

struct StorageData {
    var totalGB: Double = 0
    var usedGB: Double = 0
    var freeGB: Double = 0
    var type: String = "SSD"
    var fileSystem: String = "APFS"
    var smartStatus: String = "Verified"
    
    var usagePercent: Double {
        totalGB > 0 ? (usedGB / totalGB) * 100 : 0
    }
    
    var level: HealthLevel {
        if usagePercent < 70 { return .excellent }
        else if usagePercent < 85 { return .good }
        else if usagePercent < 95 { return .warning }
        else { return .critical }
    }
}

struct NetworkData {
    var wifiSSID: String = "—"
    var wifiSignal: Int = 0
    var wifiChannel: Int = 0
    var wifiSpeed: String = "—"
    var localIP: String = "—"
    var externalIP: String = "—"
    var macAddress: String = "—"
    var isWifiOn: Bool = false
    var bluetoothVersion: String = "—"
    var interfaceName: String = "en0"
}

struct DisplayData {
    var name: String = "—"
    var resolution: String = "—"
    var isRetina: Bool = false
}

struct ProcessInfo: Identifiable {
    let id = UUID()
    var pid: Int = 0
    var name: String = ""
    var cpuPercent: Double = 0
    var memMB: Double = 0
    var user: String = ""
}
