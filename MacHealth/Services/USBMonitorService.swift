import Foundation
import Combine

class USBMonitorService: ObservableObject {
    @Published var devices: [USBDevice] = []
    @Published var isScanning = false
    
    private var timer: Timer?
    
    func startMonitoring() {
        stopMonitoring()
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
            let output = Shell.systemProfiler("SPUSBDataType")
            let parsed = self?.parseUSBDevices(output) ?? []
            
            DispatchQueue.main.async {
                self?.devices = parsed
                self?.isScanning = false
            }
        }
    }
    
    private func parseUSBDevices(_ text: String) -> [USBDevice] {
        var devices: [USBDevice] = []
        var currentDevice: USBDevice?
        var pendingName = ""

        func appendCurrentDevice() {
            guard let device = currentDevice,
                  device.vendorID != "—" || device.productID != "—" else { return }
            if !devices.contains(where: {
                $0.name == device.name && $0.vendorID == device.vendorID && $0.productID == device.productID && $0.serialNumber == device.serialNumber
            }) {
                devices.append(device)
            }
        }
        
        for line in text.components(separatedBy: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            let indentation = line.prefix { $0 == " " || $0 == "\t" }.count

            // system_profiler використовує рядок із двокрапкою як заголовок пристрою.
            // Властивості на кшталт "Vendor ID:" відсіюємо окремо.
            if indentation >= 4,
               trimmed.hasSuffix(":"),
               !trimmed.hasPrefix("Product ID:"),
               !trimmed.hasPrefix("Vendor ID:"),
               !trimmed.hasPrefix("Serial Number:"),
               !trimmed.hasPrefix("Manufacturer:"),
               !trimmed.hasPrefix("Speed:") {
                appendCurrentDevice()
                currentDevice = nil
                pendingName = String(trimmed.dropLast()).trimmingCharacters(in: .whitespaces)
                continue
            }

            if trimmed.hasPrefix("Product ID:") {
                if currentDevice == nil {
                    currentDevice = USBDevice(name: pendingName.isEmpty ? "USB пристрій" : pendingName)
                }
                currentDevice?.productID = trimmed.replacingOccurrences(of: "Product ID:", with: "").trimmingCharacters(in: .whitespaces)
            } else if trimmed.hasPrefix("Vendor ID:") {
                if currentDevice == nil {
                    currentDevice = USBDevice(name: pendingName.isEmpty ? "USB пристрій" : pendingName)
                }
                currentDevice?.vendorID = trimmed.replacingOccurrences(of: "Vendor ID:", with: "").trimmingCharacters(in: .whitespaces)
            } else if trimmed.hasPrefix("Serial Number:") {
                currentDevice?.serialNumber = trimmed.replacingOccurrences(of: "Serial Number:", with: "").trimmingCharacters(in: .whitespaces)
            } else if trimmed.hasPrefix("Speed:") {
                currentDevice?.speed = trimmed.replacingOccurrences(of: "Speed:", with: "").trimmingCharacters(in: .whitespaces)
            } else if trimmed.hasPrefix("Manufacturer:") {
                currentDevice?.manufacturer = trimmed.replacingOccurrences(of: "Manufacturer:", with: "").trimmingCharacters(in: .whitespaces)
            }
        }
        
        appendCurrentDevice()
        
        // Фільтруємо внутрішні хаби
        return devices.filter { !$0.name.contains("Hub") || $0.manufacturer != "—" }
    }
}
