import Foundation
import AppKit

class ReportService {
    
    static func generateReport(mac: MacDiagService, phone: iPhoneService?, network: NetworkService?) -> String {
        let date = DateFormatter.localizedString(from: Date(), dateStyle: .medium, timeStyle: .short)
        
        var report = """
        ╔═══════════════════════════════════════════════════════╗
        ║          MacHealth v2.0 — Звіт діагностики            ║
        ╚═══════════════════════════════════════════════════════╝
        
        📅 Дата: \(date)
        🏥 Загальний стан: \(mac.overallHealth.rawValue)
        
        ═══════════════════════════════════════════════════════
         💻 СИСТЕМА
        ═══════════════════════════════════════════════════════
        Модель:          \(mac.systemInfo.modelName)
        Ідентифікатор:   \(mac.systemInfo.modelIdentifier)
        Серійний номер:  \(mac.systemInfo.serialNumber)
        macOS:           \(mac.systemInfo.osVersion)
        Чіп:             \(mac.systemInfo.chip)
        Пам'ять:         \(mac.systemInfo.memory)
        Час роботи:      \(mac.systemInfo.uptime)
        
        ═══════════════════════════════════════════════════════
         🔋 БАТАРЕЯ
        ═══════════════════════════════════════════════════════
        Здоров'я:        \(mac.battery.healthDisplay)
        Стан:            \(mac.battery.condition)
        Цикли:           \(mac.battery.cycleCount)
        Повна ємність:   \(mac.battery.maxCapacity) mAh
        Заводська:       \(mac.battery.designCapacity) mAh
        Поточний заряд:  \(mac.battery.currentCharge) mAh (\(mac.battery.chargeDisplay))
        Температура:     \(mac.battery.temperatureDisplay)
        Напруга:         \(String(format: "%.2f В", mac.battery.voltage))
        Зарядка:         \(mac.battery.isCharging ? "Так" : "Ні")
        
        ═══════════════════════════════════════════════════════
         🖥 ПРОЦЕСОР
        ═══════════════════════════════════════════════════════
        Модель:          \(mac.cpu.name)
        Ядра:            \(mac.cpu.cores) (P:\(mac.cpu.perfCores) E:\(mac.cpu.effCores))
        Навантаження:    \(mac.cpu.usage.formattedPercent)
        
        ═══════════════════════════════════════════════════════
         🎮 ГРАФІКА
        ═══════════════════════════════════════════════════════
        GPU:             \(mac.gpu.name)
        Ядра:            \(mac.gpu.cores > 0 ? "\(mac.gpu.cores)" : "—")
        Metal:           \(mac.gpu.metal)
        
        ═══════════════════════════════════════════════════════
         🧠 ОЗП
        ═══════════════════════════════════════════════════════
        Всього:          \(mac.ram.totalGB.formattedGB)
        Використано:     \(mac.ram.usedGB.formattedGB) (\(mac.ram.usagePercent.formattedPercent))
        Вільно:          \(mac.ram.freeGB.formattedGB)
        Тип:             \(mac.ram.type)
        
        ═══════════════════════════════════════════════════════
         💾 СХОВИЩЕ
        ═══════════════════════════════════════════════════════
        Всього:          \(mac.storage.totalGB.formattedGB)
        Використано:     \(mac.storage.usedGB.formattedGB) (\(mac.storage.usagePercent.formattedPercent))
        Вільно:          \(mac.storage.freeGB.formattedGB)
        Тип:             \(mac.storage.type)
        SMART:           \(mac.storage.smartStatus)
        
        ═══════════════════════════════════════════════════════
         🌐 МЕРЕЖА
        ═══════════════════════════════════════════════════════
        Wi-Fi:           \(mac.network.wifiSSID)
        Сигнал:          \(mac.network.signalDisplay)
        Канал:           \(mac.network.channelDisplay)
        Швидкість:       \(mac.network.wifiSpeed)
        Точка доступу:   \(mac.network.wifiBSSID)
        IP:              \(mac.network.localIP)
        MAC:             \(mac.network.macAddress)
        
        ═══════════════════════════════════════════════════════
         🖥 ДИСПЛЕЙ
        ═══════════════════════════════════════════════════════
        Тип:             \(mac.display.name)
        Роздільність:    \(mac.display.resolution)
        Retina:          \(mac.display.isRetina ? "Так" : "Ні")
        
        """
        
        // iPhone section
        if let p = phone, p.phone.isConnected {
            report += """
            
            ═══════════════════════════════════════════════════════
             📱 iPHONE
            ═══════════════════════════════════════════════════════
            Ім'я:            \(p.phone.deviceName)
            Модель:          \(p.phone.modelName)
            Серійний №:      \(p.phone.serialNumber)
            IMEI:            \(p.phone.imei)
            iOS:             \(p.phone.iosVersion)
            Батарея:         \(p.phone.batteryLevel)%
            Пам'ять:         \(p.phone.totalStorage)
            Вільно:          \(p.phone.freeStorage)
            Активація:       \(p.phone.activationStatus)
            
            """
        }
        
        report += """
        
        ═══════════════════════════════════════════════════════
        
        Згенеровано MacHealth v2.0
        https://github.com/xott/MacHealth
        
        """
        
        return report
    }
    
    static func saveReport(_ content: String) {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.plainText]
        panel.nameFieldStringValue = "MacHealth_Report_\(dateString()).txt"
        panel.title = "Зберегти звіт"
        
        panel.begin { response in
            if response == .OK, let url = panel.url {
                try? content.write(to: url, atomically: true, encoding: .utf8)
            }
        }
    }
    
    static func copyToClipboard(_ content: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(content, forType: .string)
    }
    
    private static func dateString() -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd_HH-mm"
        return fmt.string(from: Date())
    }
}
