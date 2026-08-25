import Foundation
import AppKit
import Combine

final class iPhoneService: ObservableObject {
    @Published var phone = PhoneData()
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var hasLibimobiledevice = false
    @Published var availableTools: Set<String> = []
    @Published var isBackingUp = false
    @Published var backupStatus: String?
    @Published var backups: [LocalDeviceBackup] = []

    private var backupProcess: Process?

    private let requiredTools = ["idevice_id", "ideviceinfo", "idevicepair"]

    var missingTools: [String] {
        requiredTools.filter { !availableTools.contains($0) }
    }

    var canCreateBackup: Bool {
        toolPath(for: "idevicebackup2") != nil && phone.trustState == .trusted
    }

    func chooseBackupDestination() {
        guard canCreateBackup else {
            backupStatus = "Для бекапу потрібні libimobiledevice, підключений пристрій і підтверджена довіра."
            return
        }

        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Зберегти бекап"
        panel.message = "Оберіть папку. MacHealth створить у ній окрему папку бекапу для цього пристрою."
        if panel.runModal() == .OK, let url = panel.url {
            startBackup(in: url)
        }
    }

    private func startBackup(in rootURL: URL) {
        guard !isBackingUp,
              let executable = toolPath(for: "idevicebackup2"),
              Self.isValidDeviceID(phone.deviceID) else { return }

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let backupURL = rootURL
            .appendingPathComponent("MacHealth Backups", isDirectory: true)
            .appendingPathComponent(phone.deviceID, isDirectory: true)
            .appendingPathComponent(formatter.string(from: Date()), isDirectory: true)

        do {
            try FileManager.default.createDirectory(at: backupURL, withIntermediateDirectories: true)
            let process = Process()
            process.executableURL = URL(fileURLWithPath: executable)
            process.arguments = ["-u", phone.deviceID, "backup", backupURL.path]
            process.standardOutput = FileHandle.nullDevice
            process.standardError = FileHandle.nullDevice
            process.terminationHandler = { [weak self] process in
                DispatchQueue.main.async {
                    self?.isBackingUp = false
                    self?.backupProcess = nil
                    self?.backupStatus = process.terminationStatus == 0
                        ? "Бекап створено: \(backupURL.lastPathComponent)"
                        : "Не вдалося створити бекап. Переконайтеся, що iPhone розблокований і підтверджено довіру."
                    if process.terminationStatus == 0 {
                        self?.backups.insert(LocalDeviceBackup(url: backupURL, createdAt: Date()), at: 0)
                    }
                }
            }
            backupProcess = process
            isBackingUp = true
            backupStatus = "Створюється локальний бекап… Не від’єднуйте пристрій."
            try process.run()
        } catch {
            isBackingUp = false
            backupProcess = nil
            backupStatus = "Не вдалося запустити бекап: \(error.localizedDescription)"
        }
    }
    
    func checkAndConnect() {
        isLoading = true
        errorMessage = nil
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let tools = Set(self?.requiredTools.filter { self?.toolPath(for: $0) != nil } ?? [])
            let hasLib = tools.contains("idevice_id") && tools.contains("ideviceinfo")
            
            DispatchQueue.main.async {
                self?.hasLibimobiledevice = hasLib
                self?.availableTools = tools
            }
            
            if hasLib {
                self?.fetchViaLibimobiledevice()
            } else {
                self?.fetchViaUSB()
            }
        }
    }
    
    private func fetchViaLibimobiledevice() {
        let devices = Shell.run("\(tool("idevice_id")) -l 2>/dev/null")
        let deviceID = devices.components(separatedBy: .newlines).first { Self.isValidDeviceID($0) } ?? ""
        
        if deviceID.isEmpty {
            DispatchQueue.main.async { [weak self] in
                self?.phone.isConnected = false
                self?.errorMessage = "iPhone не знайдено. Підключіть через USB та натисніть «Довіряти»."
                self?.isLoading = false
            }
            return
        }

        let trustState = checkTrust(deviceID: deviceID)
        let prefix = "\(tool("ideviceinfo")) -u \(deviceID)"
        let name = Shell.run("\(prefix) -k DeviceName 2>/dev/null")
        let productType = Shell.run("\(prefix) -k ProductType 2>/dev/null")
        let serial = Shell.run("\(prefix) -k SerialNumber 2>/dev/null")
        let ios = Shell.run("\(prefix) -k ProductVersion 2>/dev/null")
        let build = Shell.run("\(prefix) -k BuildVersion 2>/dev/null")
        let wifi = Shell.run("\(prefix) -k WiFiAddress 2>/dev/null")
        let bt = Shell.run("\(prefix) -k BluetoothAddress 2>/dev/null")
        let imei = Shell.run("\(prefix) -k InternationalMobileEquipmentIdentity 2>/dev/null")
        let battLevel = Shell.run("\(prefix) -q com.apple.mobile.battery -k BatteryCurrentCapacity 2>/dev/null")
        let activation = Shell.run("\(prefix) -k ActivationState 2>/dev/null")
        let totalDisk = Shell.run("\(prefix) -q com.apple.disk_usage -k TotalDiskCapacity 2>/dev/null")
        let freeDisk = Shell.run("\(prefix) -q com.apple.disk_usage -k AmountDataAvailable 2>/dev/null")
        
        let modelName = PhoneData.modelMap[productType] ?? productType
        
        DispatchQueue.main.async { [weak self] in
            self?.phone = PhoneData(
                deviceID: deviceID,
                deviceName: name.orDash,
                modelName: modelName,
                productType: productType.orDash,
                serialNumber: serial.orDash,
                imei: imei.orDash,
                iosVersion: ios.isEmpty ? "—" : "iOS \(ios)",
                buildVersion: build.orDash,
                wifiMAC: wifi.orDash,
                bluetoothMAC: bt.orDash,
                batteryLevel: Int(battLevel),
                batteryHealth: nil,
                totalStorage: self?.formatBytes(totalDisk) ?? "—",
                freeStorage: self?.formatBytes(freeDisk) ?? "—",
                activationStatus: self?.translateActivation(activation) ?? "—",
                isConnected: true,
                trustState: trustState,
                connection: "USB / libimobiledevice"
            )
            if trustState == .needsTrust {
                self?.errorMessage = "Розблокуйте пристрій і натисніть «Довіряти» — детальні дані та бекапи стануть доступними після pairing."
            }
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
                isConnected: true,
                connection: "USB / базове виявлення"
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

    private func checkTrust(deviceID: String) -> DeviceTrustState {
        guard toolPath(for: "idevicepair") != nil else { return .unavailable }
        let status = Shell.run("\(tool("idevicepair")) -u \(deviceID) validate >/dev/null 2>&1; echo $?")
        return status == "0" ? .trusted : .needsTrust
    }

    private func toolPath(for tool: String) -> String? {
        let candidates = ["/opt/homebrew/bin", "/usr/local/bin", "/usr/bin"]
        for directory in candidates {
            let path = "\(directory)/\(tool)"
            if FileManager.default.isExecutableFile(atPath: path) { return path }
        }
        let fromPath = Shell.run("command -v \(tool) 2>/dev/null")
        return fromPath.isEmpty ? nil : fromPath
    }

    private func tool(_ name: String) -> String {
        toolPath(for: name) ?? name
    }

    private static func isValidDeviceID(_ value: String) -> Bool {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard (16...64).contains(trimmed.count) else { return false }
        return trimmed.unicodeScalars.allSatisfy { CharacterSet.alphanumerics.contains($0) || $0 == "-" }
    }
}
