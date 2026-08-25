import Foundation
import Combine

class iPhoneService: ObservableObject {
    @Published var phone = PhoneData()
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var hasLibimobiledevice = false
    
    func checkAndConnect() {
        isLoading = true
        errorMessage = nil
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let toolPath = Shell.run("which ideviceinfo 2>/dev/null")
            let hasLib = !toolPath.isEmpty
            
            DispatchQueue.main.async {
                self?.hasLibimobiledevice = hasLib
            }
            
            if hasLib {
                self?.fetchViaLibimobiledevice()
            } else {
                self?.fetchViaUSB()
            }
        }
    }
    
    private func fetchViaLibimobiledevice() {
        let devices = Shell.run("idevice_id -l 2>/dev/null")
        
        if devices.isEmpty {
            DispatchQueue.main.async { [weak self] in
                self?.phone.isConnected = false
                self?.errorMessage = "iPhone не знайдено. Підключіть через USB та натисніть «Довіряти»."
                self?.isLoading = false
            }
            return
        }
        
        let name = Shell.run("ideviceinfo -k DeviceName 2>/dev/null")
        let productType = Shell.run("ideviceinfo -k ProductType 2>/dev/null")
        let serial = Shell.run("ideviceinfo -k SerialNumber 2>/dev/null")
        let ios = Shell.run("ideviceinfo -k ProductVersion 2>/dev/null")
        let build = Shell.run("ideviceinfo -k BuildVersion 2>/dev/null")
        let wifi = Shell.run("ideviceinfo -k WiFiAddress 2>/dev/null")
        let bt = Shell.run("ideviceinfo -k BluetoothAddress 2>/dev/null")
        let imei = Shell.run("ideviceinfo -k InternationalMobileEquipmentIdentity 2>/dev/null")
        let battLevel = Shell.run("ideviceinfo -q com.apple.mobile.battery -k BatteryCurrentCapacity 2>/dev/null")
        let activation = Shell.run("ideviceinfo -k ActivationState 2>/dev/null")
        let totalDisk = Shell.run("ideviceinfo -q com.apple.disk_usage -k TotalDiskCapacity 2>/dev/null")
        let freeDisk = Shell.run("ideviceinfo -q com.apple.disk_usage -k AmountDataAvailable 2>/dev/null")
        
        let modelName = PhoneData.modelMap[productType] ?? productType
        
        DispatchQueue.main.async { [weak self] in
            self?.phone = PhoneData(
                deviceName: name.orDash,
                modelName: modelName,
                productType: productType.orDash,
                serialNumber: serial.orDash,
                imei: imei.orDash,
                iosVersion: ios.isEmpty ? "—" : "iOS \(ios)",
                buildVersion: build.orDash,
                wifiMAC: wifi.orDash,
                bluetoothMAC: bt.orDash,
                batteryLevel: Int(battLevel) ?? 0,
                batteryHealth: 100,
                totalStorage: self?.formatBytes(totalDisk) ?? "—",
                freeStorage: self?.formatBytes(freeDisk) ?? "—",
                activationStatus: self?.translateActivation(activation) ?? "—",
                isConnected: true
            )
            self?.isLoading = false
        }
    }
    
    private func fetchViaUSB() {
        let usb = Shell.systemProfiler("SPUSBDataType")
        let hasPhone = usb.contains("iPhone") || usb.contains("iPad")
        
        if !hasPhone {
            DispatchQueue.main.async { [weak self] in
                self?.phone.isConnected = false
                self?.errorMessage = "iPhone не виявлено через USB.\n\nДля повної діагностики встановіть:\nbrew install libimobiledevice"
                self?.isLoading = false
            }
            return
        }
        
        DispatchQueue.main.async { [weak self] in
            self?.phone = PhoneData(
                deviceName: "iPhone",
                modelName: "Підключено (базова інформація)",
                isConnected: true
            )
            self?.errorMessage = "Для повної діагностики встановіть libimobiledevice:\nbrew install libimobiledevice"
            self?.isLoading = false
        }
    }
    
    private func formatBytes(_ str: String) -> String {
        guard let bytes = Double(str) else { return "—" }
        let gb = bytes / 1_073_741_824
        return gb >= 1 ? String(format: "%.1f ГБ", gb) : String(format: "%.0f МБ", bytes / 1_048_576)
    }
    
    private func translateActivation(_ state: String) -> String {
        switch state.lowercased() {
        case "activated": return "Активовано"
        case "unactivated": return "Не активовано"
        default: return state.orDash
        }
    }
}
