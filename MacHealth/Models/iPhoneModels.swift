import Foundation

enum DeviceTrustState: String {
    case trusted = "Довіру підтверджено"
    case needsTrust = "Потрібне підтвердження довіри"
    case unavailable = "Не перевірено"

    var icon: String {
        switch self {
        case .trusted: return "checkmark.shield.fill"
        case .needsTrust: return "lock.trianglebadge.exclamationmark"
        case .unavailable: return "questionmark.shield"
        }
    }

    var level: HealthLevel {
        switch self {
        case .trusted: return .excellent
        case .needsTrust: return .warning
        case .unavailable: return .unknown
        }
    }
}

struct LocalDeviceBackup: Identifiable {
    let id = UUID()
    let url: URL
    let createdAt: Date

    var title: String {
        createdAt.formatted(date: .abbreviated, time: .shortened)
    }
}

enum DeviceOperationKind: String, Identifiable {
    case backup = "Створення бекапу"
    case restoreBackup = "Відновлення бекапу"
    case installApp = "Встановлення програми"
    case uninstallApp = "Видалення програми"
    case updateFirmware = "Оновлення iOS/iPadOS"
    case eraseFirmware = "Повне відновлення IPSW"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .backup: return "externaldrive.badge.plus"
        case .restoreBackup: return "arrow.counterclockwise"
        case .installApp: return "square.and.arrow.down"
        case .uninstallApp: return "trash"
        case .updateFirmware: return "arrow.triangle.2.circlepath"
        case .eraseFirmware: return "exclamationmark.triangle"
        }
    }

    var isDestructive: Bool {
        switch self {
        case .restoreBackup, .uninstallApp, .eraseFirmware: return true
        case .backup, .installApp, .updateFirmware: return false
        }
    }
}

struct DeviceOperationState {
    var kind: DeviceOperationKind?
    var isRunning = false
    var status = "Готово"
    var log = ""
    var startedAt: Date?
    var finishedAt: Date?
    var exitCode: Int32?

    var hasResult: Bool { finishedAt != nil }
    var succeeded: Bool { exitCode == 0 }
}

struct ManagedApp: Identifiable, Hashable {
    let bundleIdentifier: String
    let name: String
    let version: String

    var id: String { bundleIdentifier }
}

struct IPSWSelection {
    let url: URL
    let isVerified: Bool
    let summary: String
}

struct PhoneData {
    var deviceID: String = "—"
    var deviceName: String = "—"
    var modelName: String = "—"
    var productType: String = "—"
    var serialNumber: String = "—"
    var imei: String = "—"
    var iosVersion: String = "—"
    var buildVersion: String = "—"
    var wifiMAC: String = "—"
    var bluetoothMAC: String = "—"
    /// Поточний заряд, якщо його віддав авторизований iOS-пристрій.
    var batteryLevel: Int? = nil
    /// Maximum Capacity не входить до стандартного протоколу iOS. Не підставляємо 100%.
    var batteryHealth: Int? = nil
    var totalStorage: String = "—"
    var freeStorage: String = "—"
    var activationStatus: String = "—"
    var isConnected: Bool = false
    var trustState: DeviceTrustState = .unavailable
    var connection: String = "USB"
    
    var batteryHealthDisplay: String {
        guard let batteryHealth else { return "Недоступно" }
        return "\(batteryHealth)%"
    }

    var batteryHealthLevel: HealthLevel? {
        guard let batteryHealth else { return nil }
        if batteryHealth >= 85 { return .excellent }
        else if batteryHealth >= 70 { return .good }
        else if batteryHealth >= 50 { return .warning }
        else { return .critical }
    }
    
    static let modelMap: [String: String] = [
        "iPhone17,1": "iPhone 16 Pro",
        "iPhone17,2": "iPhone 16 Pro Max",
        "iPhone17,3": "iPhone 16",
        "iPhone17,4": "iPhone 16 Plus",
        "iPhone16,1": "iPhone 15 Pro",
        "iPhone16,2": "iPhone 15 Pro Max",
        "iPhone15,4": "iPhone 15",
        "iPhone15,5": "iPhone 15 Plus",
        "iPhone15,2": "iPhone 14 Pro",
        "iPhone15,3": "iPhone 14 Pro Max",
        "iPhone14,7": "iPhone 14",
        "iPhone14,8": "iPhone 14 Plus",
        "iPhone14,5": "iPhone 13",
        "iPhone14,4": "iPhone 13 mini",
        "iPhone14,2": "iPhone 13 Pro",
        "iPhone14,3": "iPhone 13 Pro Max",
        "iPhone13,2": "iPhone 12",
        "iPhone13,1": "iPhone 12 mini",
        "iPhone13,3": "iPhone 12 Pro",
        "iPhone13,4": "iPhone 12 Pro Max",
        "iPhone12,1": "iPhone 11",
        "iPhone12,3": "iPhone 11 Pro",
        "iPhone12,5": "iPhone 11 Pro Max",
        "iPhone11,8": "iPhone XR",
        "iPhone11,2": "iPhone XS",
        "iPhone11,6": "iPhone XS Max",
        "iPhone10,6": "iPhone X",
    ]
}

struct USBDevice: Identifiable {
    let id = UUID()
    var name: String = "—"
    var vendorID: String = "—"
    var productID: String = "—"
    var serialNumber: String = "—"
    var speed: String = "—"
    var manufacturer: String = "—"
}
