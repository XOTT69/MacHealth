import Foundation

// MARK: - Health Level

enum HealthLevel: String, CaseIterable {
    case excellent = "Відмінно"
    case good = "Добре"
    case warning = "Потребує уваги"
    case critical = "Критично"
    case unknown = "Невідомо"
    
    var icon: String {
        switch self {
        case .excellent: return "checkmark.circle.fill"
        case .good: return "checkmark.circle"
        case .warning: return "exclamationmark.triangle.fill"
        case .critical: return "xmark.circle.fill"
        case .unknown: return "questionmark.circle"
        }
    }
}

// MARK: - Sidebar Navigation

enum SidebarItem: String, CaseIterable, Identifiable {
    case dashboard = "Панель"
    case macOverview = "Mac огляд"
    case macBattery = "Батарея"
    case macStorage = "Сховище"
    case macProcesses = "Процеси"
    case iPhone = "iPhone"
    case network = "Мережа"
    case speedTest = "Speed Test"
    case ping = "Ping"
    case localScan = "Сканер мережі"
    case usb = "USB пристрої"
    case hardwareTest = "Тести"
    case report = "Звіт"
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .dashboard: return "gauge.with.dots.needle.33percent"
        case .macOverview: return "laptopcomputer"
        case .macBattery: return "battery.75percent"
        case .macStorage: return "internaldrive"
        case .macProcesses: return "cpu"
        case .iPhone: return "iphone"
        case .network: return "wifi"
        case .speedTest: return "speedometer"
        case .ping: return "network"
        case .localScan: return "antenna.radiowaves.left.and.right"
        case .usb: return "cable.connector"
        case .hardwareTest: return "wrench.and.screwdriver"
        case .report: return "doc.text.magnifyingglass"
        }
    }
    
    var section: String {
        switch self {
        case .dashboard: return "Головна"
        case .macOverview, .macBattery, .macStorage, .macProcesses: return "Mac"
        case .iPhone: return "iPhone"
        case .network, .speedTest, .ping, .localScan: return "Мережа"
        case .usb: return "Пристрої"
        case .hardwareTest: return "Тести"
        case .report: return "Звіти"
        }
    }
}

// MARK: - Recommendation

struct Recommendation: Identifiable {
    let id = UUID()
    let category: String
    let level: HealthLevel
    let title: String
    let description: String
    let cost: String?
}
