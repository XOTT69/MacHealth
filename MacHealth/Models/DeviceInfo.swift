import Foundation

// MARK: - Mac Models

struct MacInfo {
    var modelName: String = "—"
    var modelIdentifier: String = "—"
    var serialNumber: String = "—"
    var osVersion: String = "—"
    var chipInfo: String = "—"
    var uptime: String = "—"
}

struct BatteryInfo {
    var cycleCount: Int = 0
    var maxCapacity: Int = 100
    var designCapacity: Int = 100
    var healthPercentage: Double = 100.0
    var isCharging: Bool = false
    var currentCharge: Int = 0
    var temperature: Double = 0.0
    var condition: String = "Нормальний"
    var timeRemaining: String = "—"
    
    var healthStatus: HealthStatus {
        if healthPercentage >= 80 { return .good }
        else if healthPercentage >= 60 { return .warning }
        else { return .critical }
    }
}

struct CPUInfo {
    var modelName: String = "—"
    var coreCount: Int = 0
    var performanceCores: Int = 0
    var efficiencyCores: Int = 0
    var currentUsage: Double = 0.0
    var temperature: Double = 0.0
    
    var usageStatus: HealthStatus {
        if currentUsage < 70 { return .good }
        else if currentUsage < 90 { return .warning }
        else { return .critical }
    }
}

struct GPUInfo {
    var modelName: String = "—"
    var coreCount: Int = 0
    var metalSupport: String = "—"
}

struct RAMInfo {
    var totalGB: Double = 0.0
    var usedGB: Double = 0.0
    var freeGB: Double = 0.0
    var type: String = "—"
    var usagePercentage: Double = 0.0
    
    var usageStatus: HealthStatus {
        if usagePercentage < 70 { return .good }
        else if usagePercentage < 90 { return .warning }
        else { return .critical }
    }
}

struct StorageInfo {
    var totalGB: Double = 0.0
    var usedGB: Double = 0.0
    var freeGB: Double = 0.0
    var type: String = "—" // SSD / HDD
    var fileSystem: String = "—"
    var usagePercentage: Double = 0.0
    var smartStatus: String = "—"
    
    var usageStatus: HealthStatus {
        if usagePercentage < 80 { return .good }
        else if usagePercentage < 95 { return .warning }
        else { return .critical }
    }
    
    var smartHealthStatus: HealthStatus {
        if smartStatus.lowercased().contains("verified") || smartStatus.lowercased().contains("ok") {
            return .good
        } else if smartStatus == "—" {
            return .warning
        } else {
            return .critical
        }
    }
}

struct NetworkInfo {
    var wifiName: String = "—"
    var wifiMAC: String = "—"
    var localIP: String = "—"
    var bluetoothVersion: String = "—"
    var isWifiEnabled: Bool = false
    var isBluetoothEnabled: Bool = false
}

struct DisplayInfo {
    var name: String = "—"
    var resolution: String = "—"
    var displayType: String = "—" // Retina / Standard
    var size: String = "—"
}

// MARK: - iPhone Models

struct iPhoneInfo {
    var deviceName: String = "—"
    var modelName: String = "—"
    var serialNumber: String = "—"
    var imei: String = "—"
    var iosVersion: String = "—"
    var buildVersion: String = "—"
    var wifiMAC: String = "—"
    var bluetoothMAC: String = "—"
    var batteryLevel: Int = 0
    var batteryHealth: Int = 100
    var totalStorage: String = "—"
    var usedStorage: String = "—"
    var freeStorage: String = "—"
    var activationStatus: String = "—"
    var isConnected: Bool = false
}

// MARK: - Health Status

enum HealthStatus {
    case good
    case warning
    case critical
    
    var color: String {
        switch self {
        case .good: return "green"
        case .warning: return "orange"
        case .critical: return "red"
        }
    }
    
    var icon: String {
        switch self {
        case .good: return "checkmark.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .critical: return "xmark.circle.fill"
        }
    }
    
    var label: String {
        switch self {
        case .good: return "Відмінно"
        case .warning: return "Потребує уваги"
        case .critical: return "Критично"
        }
    }
}

// MARK: - Recommendation

struct Recommendation: Identifiable {
    let id = UUID()
    let category: String
    let status: HealthStatus
    let title: String
    let description: String
    let estimatedCost: String?
}
