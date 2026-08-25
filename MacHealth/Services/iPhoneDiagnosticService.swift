import Foundation

class iPhoneDiagnosticService: ObservableObject {
    @Published var phoneInfo = iPhoneInfo()
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var recommendations: [Recommendation] = []
    
    func checkConnection() {
        isLoading = true
        errorMessage = nil
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            // Перевіряємо чи доступний ideviceinfo (libimobiledevice)
            let checkTool = ShellExecutor.execute("which ideviceinfo 2>/dev/null")
            
            if checkTool.isEmpty {
                // Пробуємо альтернативний метод через system_profiler
                self?.fetchViaSytemProfiler()
            } else {
                self?.fetchViaLibimobiledevice()
            }
        }
    }
    
    // MARK: - Через libimobiledevice (якщо встановлено)
    
    private func fetchViaLibimobiledevice() {
        let deviceList = ShellExecutor.execute("idevice_id -l 2>/dev/null")
        
        if deviceList.isEmpty {
            DispatchQueue.main.async { [weak self] in
                self?.phoneInfo.isConnected = false
                self?.errorMessage = "iPhone не знайдено. Підключіть пристрій через USB та натисніть 'Довіряти' на iPhone."
                self?.isLoading = false
            }
            return
        }
        
        let deviceName = ShellExecutor.execute("ideviceinfo -k DeviceName 2>/dev/null")
        let modelNumber = ShellExecutor.execute("ideviceinfo -k ProductType 2>/dev/null")
        let serialNumber = ShellExecutor.execute("ideviceinfo -k SerialNumber 2>/dev/null")
        let iosVersion = ShellExecutor.execute("ideviceinfo -k ProductVersion 2>/dev/null")
        let buildVersion = ShellExecutor.execute("ideviceinfo -k BuildVersion 2>/dev/null")
        let wifiMAC = ShellExecutor.execute("ideviceinfo -k WiFiAddress 2>/dev/null")
        let btMAC = ShellExecutor.execute("ideviceinfo -k BluetoothAddress 2>/dev/null")
        let imei = ShellExecutor.execute("ideviceinfo -k InternationalMobileEquipmentIdentity 2>/dev/null")
        
        // Батарея
        let batteryLevel = ShellExecutor.execute("ideviceinfo -q com.apple.mobile.battery -k BatteryCurrentCapacity 2>/dev/null")
        let batteryHealth = ShellExecutor.execute("ideviceinfo -q com.apple.mobile.battery -k NominalChargeCapacity 2>/dev/null")
        
        // Пам'ять
        let totalDisk = ShellExecutor.execute("ideviceinfo -q com.apple.disk_usage -k TotalDiskCapacity 2>/dev/null")
        let freeDisk = ShellExecutor.execute("ideviceinfo -q com.apple.disk_usage -k AmountDataAvailable 2>/dev/null")
        
        // Статус активації
        let activationState = ShellExecutor.execute("ideviceinfo -k ActivationState 2>/dev/null")
        
        DispatchQueue.main.async { [weak self] in
            self?.phoneInfo = MacHealth.iPhoneInfo(
                deviceName: deviceName.isEmpty ? "iPhone" : deviceName,
                modelName: self?.mapModelName(modelNumber) ?? modelNumber,
                serialNumber: serialNumber.isEmpty ? "—" : serialNumber,
                imei: imei.isEmpty ? "—" : imei,
                iosVersion: iosVersion.isEmpty ? "—" : "iOS \(iosVersion)",
                buildVersion: buildVersion.isEmpty ? "—" : buildVersion,
                wifiMAC: wifiMAC.isEmpty ? "—" : wifiMAC,
                bluetoothMAC: btMAC.isEmpty ? "—" : btMAC,
                batteryLevel: Int(batteryLevel) ?? 0,
                batteryHealth: Int(batteryHealth) ?? 100,
                totalStorage: self?.formatBytes(totalDisk) ?? "—",
                usedStorage: "—",
                freeStorage: self?.formatBytes(freeDisk) ?? "—",
                activationStatus: activationState.isEmpty ? "—" : self?.translateActivation(activationState) ?? activationState,
                isConnected: true
            )
            self?.generateiPhoneRecommendations()
            self?.isLoading = false
        }
    }
    
    // MARK: - Через system_profiler (без libimobiledevice)
    
    private func fetchViaSytemProfiler() {
        let usbData = ShellExecutor.execute("system_profiler SPUSBDataType 2>/dev/null")
        
        // Шукаємо iPhone в USB пристроях
        let hasIphone = usbData.contains("iPhone") || usbData.contains("Apple Mobile Device")
        
        if !hasIphone {
            DispatchQueue.main.async { [weak self] in
                self?.phoneInfo.isConnected = false
                self?.errorMessage = "iPhone не знайдено.\n\n📋 Для повної діагностики iPhone рекомендуємо:\n1. Підключіть iPhone через USB-кабель\n2. Натисніть 'Довіряти' на iPhone\n3. Встановіть libimobiledevice: brew install libimobiledevice\n\nБез цієї бібліотеки доступна лише базова інформація."
                self?.isLoading = false
            }
            return
        }
        
        // Базова інформація з system_profiler
        let serialNumber = extractUSBValue(from: usbData, key: "Serial Number", after: "iPhone")
        let productId = extractUSBValue(from: usbData, key: "Product ID", after: "iPhone")
        
        DispatchQueue.main.async { [weak self] in
            self?.phoneInfo = MacHealth.iPhoneInfo(
                deviceName: "iPhone",
                modelName: "iPhone (підключено через USB)",
                serialNumber: serialNumber.isEmpty ? "—" : serialNumber,
                imei: "—",
                iosVersion: "—",
                buildVersion: "—",
                wifiMAC: "—",
                bluetoothMAC: "—",
                batteryLevel: 0,
                batteryHealth: 100,
                totalStorage: "—",
                usedStorage: "—",
                freeStorage: "—",
                activationStatus: "—",
                isConnected: true
            )
            self?.errorMessage = "⚠️ Для повної діагностики встановіть libimobiledevice:\nbrew install libimobiledevice\n\nПісля встановлення натисніть 'Оновити діагностику'."
            self?.isLoading = false
        }
    }
    
    // MARK: - Recommendations
    
    private func generateiPhoneRecommendations() {
        var recs: [Recommendation] = []
        
        if phoneInfo.batteryHealth > 0 && phoneInfo.batteryHealth < 80 {
            recs.append(Recommendation(
                category: "🔋 Батарея iPhone",
                status: phoneInfo.batteryHealth < 60 ? .critical : .warning,
                title: "Батарея iPhone зношена",
                description: "Здоров'я батареї: \(phoneInfo.batteryHealth)%. Рекомендуємо замінити батарею для кращої автономності.",
                estimatedCost: "₴1500–3000"
            ))
        } else if phoneInfo.batteryHealth >= 80 {
            recs.append(Recommendation(
                category: "🔋 Батарея iPhone",
                status: .good,
                title: "Батарея iPhone в нормі",
                description: "Здоров'я батареї: \(phoneInfo.batteryHealth)%. Заміна не потрібна.",
                estimatedCost: nil
            ))
        }
        
        if phoneInfo.batteryLevel > 0 && phoneInfo.batteryLevel < 20 {
            recs.append(Recommendation(
                category: "🔋 Батарея iPhone",
                status: .warning,
                title: "Низький рівень заряду",
                description: "Поточний заряд: \(phoneInfo.batteryLevel)%. Рекомендуємо зарядити пристрій.",
                estimatedCost: nil
            ))
        }
        
        recommendations = recs
    }
    
    // MARK: - Helpers
    
    private func mapModelName(_ identifier: String) -> String {
        let models: [String: String] = [
            "iPhone15,4": "iPhone 15",
            "iPhone15,5": "iPhone 15 Plus",
            "iPhone16,1": "iPhone 15 Pro",
            "iPhone16,2": "iPhone 15 Pro Max",
            "iPhone14,7": "iPhone 14",
            "iPhone14,8": "iPhone 14 Plus",
            "iPhone15,2": "iPhone 14 Pro",
            "iPhone15,3": "iPhone 14 Pro Max",
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
            "iPhone17,1": "iPhone 16 Pro",
            "iPhone17,2": "iPhone 16 Pro Max",
            "iPhone17,3": "iPhone 16",
            "iPhone17,4": "iPhone 16 Plus",
        ]
        return models[identifier] ?? identifier
    }
    
    private func formatBytes(_ bytesStr: String) -> String {
        guard let bytes = Double(bytesStr) else { return "—" }
        let gb = bytes / 1_073_741_824
        if gb >= 1 {
            return String(format: "%.1f ГБ", gb)
        } else {
            let mb = bytes / 1_048_576
            return String(format: "%.0f МБ", mb)
        }
    }
    
    private func translateActivation(_ state: String) -> String {
        switch state.lowercased() {
        case "activated": return "Активовано"
        case "unactivated": return "Не активовано"
        case "factoryactivated": return "Фабрично активовано"
        default: return state
        }
    }
    
    private func extractUSBValue(from text: String, key: String, after marker: String) -> String {
        guard let markerRange = text.range(of: marker) else { return "" }
        let afterMarker = String(text[markerRange.upperBound...])
        let lines = afterMarker.components(separatedBy: "\n")
        for line in lines {
            if line.contains(key) {
                let parts = line.components(separatedBy: ":")
                if parts.count >= 2 {
                    return parts[1].trimmingCharacters(in: .whitespaces)
                }
            }
        }
        return ""
    }
}
