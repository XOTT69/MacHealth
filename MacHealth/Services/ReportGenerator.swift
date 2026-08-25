import Foundation

class ReportGenerator {
    
    static func generateTextReport(
        macService: MacDiagnosticService,
        iPhoneService: iPhoneDiagnosticService?
    ) -> String {
        var report = """
        ╔══════════════════════════════════════════════════╗
        ║            MacHealth — Звіт діагностики          ║
        ╚══════════════════════════════════════════════════╝
        
        📅 Дата: \(formattedDate())
        🏥 Загальний стан: \(macService.overallHealth.label)
        
        ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
        📱 ІНФОРМАЦІЯ ПРО MAC
        ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
        
        Модель:           \(macService.macInfo.modelName)
        Ідентифікатор:    \(macService.macInfo.modelIdentifier)
        Серійний номер:   \(macService.macInfo.serialNumber)
        macOS:            \(macService.macInfo.osVersion)
        Процесор:         \(macService.macInfo.chipInfo)
        Час роботи:       \(macService.macInfo.uptime)
        
        ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
        🔋 БАТАРЕЯ
        ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
        
        Здоров'я:         \(String(format: "%.0f", macService.batteryInfo.healthPercentage))%
        Стан:             \(macService.batteryInfo.condition)
        Цикли заряду:     \(macService.batteryInfo.cycleCount)
        Температура:      \(String(format: "%.1f", macService.batteryInfo.temperature))°C
        Зарядка:          \(macService.batteryInfo.isCharging ? "Так" : "Ні")
        
        ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
        💻 ПРОЦЕСОР
        ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
        
        Модель:           \(macService.cpuInfo.modelName)
        Кількість ядер:   \(macService.cpuInfo.coreCount)
        Навантаження:     \(String(format: "%.1f", macService.cpuInfo.currentUsage))%
        Температура:      \(macService.cpuInfo.temperature > 0 ? String(format: "%.0f°C", macService.cpuInfo.temperature) : "Недоступно")
        
        ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
        🎮 ГРАФІКА
        ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
        
        GPU:              \(macService.gpuInfo.modelName)
        Ядра GPU:         \(macService.gpuInfo.coreCount > 0 ? "\(macService.gpuInfo.coreCount)" : "—")
        Metal:            \(macService.gpuInfo.metalSupport)
        
        ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
        🧠 ОПЕРАТИВНА ПАМ'ЯТЬ
        ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
        
        Загальна:         \(String(format: "%.0f", macService.ramInfo.totalGB)) ГБ
        Використано:      \(String(format: "%.1f", macService.ramInfo.usedGB)) ГБ (\(String(format: "%.0f", macService.ramInfo.usagePercentage))%)
        Вільно:           \(String(format: "%.1f", macService.ramInfo.freeGB)) ГБ
        Тип:              \(macService.ramInfo.type)
        
        ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
        💾 СХОВИЩЕ
        ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
        
        Загальна:         \(String(format: "%.0f", macService.storageInfo.totalGB)) ГБ
        Використано:      \(String(format: "%.0f", macService.storageInfo.usedGB)) ГБ (\(String(format: "%.0f", macService.storageInfo.usagePercentage))%)
        Вільно:           \(String(format: "%.0f", macService.storageInfo.freeGB)) ГБ
        Тип:              \(macService.storageInfo.type)
        Файлова система:  \(macService.storageInfo.fileSystem)
        SMART-статус:     \(macService.storageInfo.smartStatus)
        
        ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
        🌐 МЕРЕЖА
        ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
        
        Wi-Fi:            \(macService.networkInfo.wifiName)
        Wi-Fi MAC:        \(macService.networkInfo.wifiMAC)
        Локальна IP:      \(macService.networkInfo.localIP)
        Bluetooth:        \(macService.networkInfo.bluetoothVersion)
        
        ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
        🖥 ДИСПЛЕЙ
        ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
        
        Назва:            \(macService.displayInfo.name)
        Роздільна здатн.: \(macService.displayInfo.resolution)
        Тип:              \(macService.displayInfo.displayType)
        
        """
        
        // iPhone секція
        if let iPhone = iPhoneService, iPhone.phoneInfo.isConnected {
            report += """
            
            ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
            📱 iPHONE
            ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
            
            Ім'я:             \(iPhone.phoneInfo.deviceName)
            Модель:           \(iPhone.phoneInfo.modelName)
            Серійний номер:   \(iPhone.phoneInfo.serialNumber)
            IMEI:             \(iPhone.phoneInfo.imei)
            iOS:              \(iPhone.phoneInfo.iosVersion)
            Батарея:          \(iPhone.phoneInfo.batteryLevel)%
            Здоров'я батареї: \(iPhone.phoneInfo.batteryHealth)%
            Пам'ять:          \(iPhone.phoneInfo.totalStorage)
            Вільно:           \(iPhone.phoneInfo.freeStorage)
            Активація:        \(iPhone.phoneInfo.activationStatus)
            
            """
        }
        
        // Рекомендації
        report += """
        
        ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
        📋 РЕКОМЕНДАЦІЇ ПО РЕМОНТУ ТА ОБСЛУГОВУВАННЮ
        ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
        
        """
        
        for rec in macService.recommendations {
            let statusIcon: String
            switch rec.status {
            case .good: statusIcon = "✅"
            case .warning: statusIcon = "⚠️"
            case .critical: statusIcon = "🔴"
            }
            
            report += """
            \(statusIcon) \(rec.title)
               \(rec.description)
            """
            
            if let cost = rec.estimatedCost {
                report += """
                
                   💰 Орієнтовна вартість: \(cost)
                """
            }
            report += "\n\n"
        }
        
        report += """
        ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
        
        Згенеровано програмою MacHealth
        https://github.com/xott/MacHealth
        
        """
        
        return report
    }
    
    static func saveReport(_ content: String) -> URL? {
        let fileName = "MacHealth_Report_\(fileDate()).txt"
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let fileURL = documentsPath.appendingPathComponent(fileName)
        
        do {
            try content.write(to: fileURL, atomically: true, encoding: .utf8)
            return fileURL
        } catch {
            print("Помилка збереження звіту: \(error)")
            return nil
        }
    }
    
    private static func formattedDate() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd.MM.yyyy HH:mm"
        formatter.locale = Locale(identifier: "uk_UA")
        return formatter.string(from: Date())
    }
    
    private static func fileDate() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm"
        return formatter.string(from: Date())
    }
}
