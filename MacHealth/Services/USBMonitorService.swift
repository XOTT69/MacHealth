import Foundation
import Combine

class USBMonitorService: ObservableObject {
    @Published var devices: [USBDevice] = []
    @Published var isScanning = false
    
    private var timer: Timer?
    
    func startMonitoring() {
        scan()
        timer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { [weak self] _ in
            self?.scan()
        }
    }
    
    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
    }
    
    func scan() {
        isScanning = true
        DispatchQueue.global(qos: .utility).async { [weak self] in
            let output = Shell.run("system_profiler SPUSBDataType 2>/dev/null")
            let parsed = self?.parseUSBDevices(output) ?? []
            
            DispatchQueue.main.async {
                self?.devices = parsed
                self?.isScanning = false
            }
        }
    }
    
    private func parseUSBDevices(_ text: String) -> [USBDevice] {
        var devices: [USBDevice] = []
        let sections = text.components(separatedBy: "\n\n")
        
        var currentDevice: USBDevice?
        
        for line in text.components(separatedBy: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            
            // Нова секція пристрою (назва без відступу після порожнього рядка)
            if !trimmed.isEmpty && !trimmed.contains(":") && !line.hasPrefix(" ") && line.count > 2 {
                // Це можливо заголовок
            }
            
            if trimmed.hasPrefix("Product ID:") {
                if currentDevice == nil { currentDevice = USBDevice() }
                currentDevice?.productID = trimmed.replacingOccurrences(of: "Product ID:", with: "").trimmingCharacters(in: .whitespaces)
            } else if trimmed.hasPrefix("Vendor ID:") {
                if currentDevice == nil { currentDevice = USBDevice() }
                currentDevice?.vendorID = trimmed.replacingOccurrences(of: "Vendor ID:", with: "").trimmingCharacters(in: .whitespaces)
            } else if trimmed.hasPrefix("Serial Number:") {
                currentDevice?.serialNumber = trimmed.replacingOccurrences(of: "Serial Number:", with: "").trimmingCharacters(in: .whitespaces)
            } else if trimmed.hasPrefix("Speed:") {
                currentDevice?.speed = trimmed.replacingOccurrences(of: "Speed:", with: "").trimmingCharacters(in: .whitespaces)
            } else if trimmed.hasPrefix("Manufacturer:") {
                currentDevice?.manufacturer = trimmed.replacingOccurrences(of: "Manufacturer:", with: "").trimmingCharacters(in: .whitespaces)
            } else if trimmed.isEmpty && currentDevice != nil {
                if let dev = currentDevice, !dev.vendorID.isEmpty || !dev.productID.isEmpty {
                    devices.append(dev)
                }
                currentDevice = nil
            }
            
            // Визначаємо назву з рядка-заголовка
            if line.hasPrefix("          ") && trimmed.hasSuffix(":") && !trimmed.contains("  ") {
                if currentDevice != nil, let dev = currentDevice {
                    if !dev.vendorID.isEmpty || !dev.productID.isEmpty {
                        devices.append(dev)
                    }
                }
                currentDevice = USBDevice()
                currentDevice?.name = String(trimmed.dropLast())
            }
        }
        
        // Останній
        if let dev = currentDevice, !dev.vendorID.isEmpty || !dev.productID.isEmpty {
            devices.append(dev)
        }
        
        // Фільтруємо внутрішні хаби
        return devices.filter { !$0.name.contains("Hub") || $0.manufacturer != "—" }
    }
}
