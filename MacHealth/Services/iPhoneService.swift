import Foundation
import AppKit
import Combine
import UniformTypeIdentifiers

final class iPhoneService: ObservableObject {
    @Published var phone = PhoneData()
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var hasLibimobiledevice = false
    @Published var availableTools: Set<String> = []
    @Published var isBackingUp = false
    @Published var backupStatus: String?
    @Published var backups: [LocalDeviceBackup] = []
    @Published var operation = DeviceOperationState()
    @Published var installedApps: [ManagedApp] = []
    @Published var isLoadingApps = false
    @Published var selectedIPSW: IPSWSelection?
    @Published var selectedIPA: URL?
    @Published var firmwareStatus: String?

    private var operationProcess: Process?
    private var operationPipe: Pipe?

    private let baseTools = ["idevice_id", "ideviceinfo", "idevicepair"]
    private let optionalTools = ["idevicebackup2", "ideviceinstaller", "idevicerestore"]
    private let backupRootsKey = "MacHealth.backupRoots"

    var missingTools: [String] {
        baseTools.filter { !availableTools.contains($0) }
    }

    var canCreateBackup: Bool { isTrusted && hasTool("idevicebackup2") }
    var canRestoreBackup: Bool { isTrusted && hasTool("idevicebackup2") && !backups.isEmpty }
    var canManageApps: Bool { isTrusted && hasTool("ideviceinstaller") }
    var canRestoreFirmware: Bool { isTrusted && hasTool("idevicerestore") && selectedIPSW?.isVerified == true }
    var isTrusted: Bool { phone.isConnected && phone.trustState == .trusted && Self.isValidDeviceID(phone.deviceID) }
    var allToolNames: [String] { baseTools + optionalTools }

    // MARK: - Connection

    func checkAndConnect() {
        guard !operation.isRunning else { return }
        isLoading = true
        errorMessage = nil

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }
            let tools = Set(self.allToolNames.filter { self.toolPath(for: $0) != nil })
            let hasLib = self.baseTools.allSatisfy { tools.contains($0) }

            DispatchQueue.main.async {
                self.hasLibimobiledevice = hasLib
                self.availableTools = tools
            }

            if hasLib {
                self.fetchViaLibimobiledevice()
            } else {
                self.fetchViaUSB()
            }
        }
    }

    private func fetchViaLibimobiledevice() {
        let devices = Shell.run(tool("idevice_id"), arguments: ["-l"]).output
        let deviceID = devices.components(separatedBy: .newlines).first { Self.isValidDeviceID($0) } ?? ""

        guard !deviceID.isEmpty else {
            DispatchQueue.main.async { [weak self] in
                self?.phone.isConnected = false
                self?.backups = []
                self?.installedApps = []
                self?.errorMessage = "iPhone або iPad не знайдено. Підключіть його через USB, розблокуйте та натисніть «Довіряти»."
                self?.isLoading = false
            }
            return
        }

        let trustState = checkTrust(deviceID: deviceID)
        let infoTool = tool("ideviceinfo")
        func info(_ key: String, domain: String? = nil) -> String {
            var arguments = ["-u", deviceID]
            if let domain { arguments += ["-q", domain] }
            arguments += ["-k", key]
            let result = Shell.run(infoTool, arguments: arguments)
            return result.succeeded ? result.output : ""
        }

        let productType = info("ProductType")
        let phoneData = PhoneData(
            deviceID: deviceID,
            deviceName: info("DeviceName").orDash,
            modelName: PhoneData.modelMap[productType] ?? productType.orDash,
            productType: productType.orDash,
            serialNumber: info("SerialNumber").orDash,
            imei: info("InternationalMobileEquipmentIdentity").orDash,
            iosVersion: info("ProductVersion").notEmpty.map { "iOS \($0)" } ?? "—",
            buildVersion: info("BuildVersion").orDash,
            wifiMAC: info("WiFiAddress").orDash,
            bluetoothMAC: info("BluetoothAddress").orDash,
            batteryLevel: Int(info("BatteryCurrentCapacity", domain: "com.apple.mobile.battery")),
            batteryHealth: nil,
            totalStorage: formatBytes(info("TotalDiskCapacity", domain: "com.apple.disk_usage")),
            freeStorage: formatBytes(info("AmountDataAvailable", domain: "com.apple.disk_usage")),
            activationStatus: translateActivation(info("ActivationState")),
            isConnected: true,
            trustState: trustState,
            connection: "USB / libimobiledevice"
        )

        DispatchQueue.main.async { [weak self] in
            self?.phone = phoneData
            self?.loadBackups(for: deviceID)
            self?.errorMessage = trustState == .needsTrust
                ? "Розблокуйте пристрій і підтвердіть довіру. Після pairing стануть доступними бекапи, керування програмами та відновлення."
                : nil
            self?.isLoading = false
            if trustState == .trusted, self?.canManageApps == true {
                self?.refreshInstalledApps()
            }
        }
    }

    private func fetchViaUSB() {
        let usb = Shell.systemProfiler("SPUSBDataType")
        let hasPhone = usb.contains("iPhone") || usb.contains("iPad")
        DispatchQueue.main.async { [weak self] in
            if hasPhone {
                self?.phone = PhoneData(deviceName: "Apple-пристрій", modelName: "Підключено (базове виявлення)", isConnected: true, connection: "USB / базове виявлення")
                self?.errorMessage = "Для повного Device Hub встановіть libimobiledevice: brew install libimobiledevice"
            } else {
                self?.phone.isConnected = false
                self?.backups = []
                self?.installedApps = []
                self?.errorMessage = "iPhone або iPad не виявлено через USB. Для повної підтримки встановіть: brew install libimobiledevice"
            }
            self?.isLoading = false
        }
    }

    // MARK: - Backups

    func chooseBackupDestination() {
        guard canCreateBackup, !operation.isRunning else {
            backupStatus = "Для бекапу потрібні довірений пристрій і idevicebackup2."
            return
        }
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Зберегти бекап"
        panel.message = "Оберіть папку. MacHealth створить у ній окремий локальний бекап для цього пристрою."
        if panel.runModal() == .OK, let url = panel.url {
            startBackup(in: url)
        }
    }

    func restoreBackup(_ backup: LocalDeviceBackup) {
        guard canRestoreBackup, !operation.isRunning, let executable = toolPath(for: "idevicebackup2") else { return }
        beginOperation(
            kind: .restoreBackup,
            executable: executable,
            arguments: ["-u", phone.deviceID, "restore", backup.url.path],
            successMessage: "Відновлення бекапу завершено. Пристрій може перезавантажитися."
        )
    }

    private func startBackup(in rootURL: URL) {
        guard let executable = toolPath(for: "idevicebackup2"), Self.isValidDeviceID(phone.deviceID) else { return }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let backupURL = rootURL
            .appendingPathComponent("MacHealth Backups", isDirectory: true)
            .appendingPathComponent(phone.deviceID, isDirectory: true)
            .appendingPathComponent(formatter.string(from: Date()), isDirectory: true)
        do {
            rememberBackupRoot(rootURL)
            try FileManager.default.createDirectory(at: backupURL, withIntermediateDirectories: true)
            beginOperation(
                kind: .backup,
                executable: executable,
                arguments: ["-u", phone.deviceID, "backup", backupURL.path],
                successMessage: "Бекап створено: \(backupURL.lastPathComponent)"
            ) { [weak self] succeeded in
                if succeeded {
                    self?.backups.insert(LocalDeviceBackup(url: backupURL, createdAt: Date()), at: 0)
                }
            }
        } catch {
            backupStatus = "Не вдалося підготувати папку бекапу: \(error.localizedDescription)"
        }
    }

    // MARK: - Apps

    func chooseIPAForInstallation() {
        guard canManageApps, !operation.isRunning else { return }
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        if let ipaType = UTType(filenameExtension: "ipa") {
            panel.allowedContentTypes = [ipaType]
        }
        panel.prompt = "Обрати IPA"
        panel.message = "Оберіть лише IPA з дійсним підписом для підключеного пристрою."
        if panel.runModal() == .OK, let url = panel.url {
            selectedIPA = url
        }
    }

    func installSelectedIPA() {
        guard canManageApps,
              let executable = toolPath(for: "ideviceinstaller"),
              let ipa = selectedIPA,
              ipa.pathExtension.lowercased() == "ipa",
              FileManager.default.fileExists(atPath: ipa.path) else { return }
        beginOperation(
            kind: .installApp,
            executable: executable,
            arguments: ["-u", phone.deviceID, "install", ipa.path],
            successMessage: "Програму встановлено."
        ) { [weak self] succeeded in
            if succeeded { self?.refreshInstalledApps() }
        }
    }

    func uninstallApp(_ app: ManagedApp) {
        guard canManageApps, let executable = toolPath(for: "ideviceinstaller") else { return }
        beginOperation(
            kind: .uninstallApp,
            executable: executable,
            arguments: ["-u", phone.deviceID, "uninstall", app.bundleIdentifier],
            successMessage: "Програму \(app.name) видалено."
        ) { [weak self] succeeded in
            if succeeded { self?.refreshInstalledApps() }
        }
    }

    func refreshInstalledApps() {
        guard canManageApps, !operation.isRunning, let executable = toolPath(for: "ideviceinstaller") else { return }
        isLoadingApps = true
        let udid = phone.deviceID
        DispatchQueue.global(qos: .utility).async { [weak self] in
            let result = Shell.run(executable, arguments: ["-u", udid, "--user", "--xml", "list"], timeout: 45)
            let apps = result.succeeded ? Self.parseApps(from: result.output) : []
            DispatchQueue.main.async {
                self?.installedApps = apps
                self?.isLoadingApps = false
            }
        }
    }

    // MARK: - Firmware

    func chooseIPSW() {
        guard hasTool("idevicerestore"), !operation.isRunning else { return }
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        if let ipswType = UTType(filenameExtension: "ipsw") {
            panel.allowedContentTypes = [ipswType]
        }
        panel.prompt = "Обрати IPSW"
        panel.message = "Оберіть локальний офіційний IPSW. MacHealth спочатку виконає перевірку архіву без відновлення."
        if panel.runModal() == .OK, let url = panel.url {
            inspectIPSW(url)
        }
    }

    func startFirmwareRestore(erasing: Bool) {
        guard canRestoreFirmware,
              let executable = toolPath(for: "idevicerestore"),
              let ipsw = selectedIPSW else { return }
        var arguments = ["-u", phone.deviceID, "-y"]
        if erasing { arguments.append("-e") }
        arguments.append(ipsw.url.path)
        beginOperation(
            kind: erasing ? .eraseFirmware : .updateFirmware,
            executable: executable,
            arguments: arguments,
            successMessage: erasing ? "Повне відновлення завершено." : "Оновлення iOS/iPadOS завершено."
        )
    }

    private func inspectIPSW(_ url: URL) {
        guard url.pathExtension.lowercased() == "ipsw",
              FileManager.default.fileExists(atPath: url.path),
              let executable = toolPath(for: "idevicerestore") else { return }
        firmwareStatus = "Перевірка IPSW…"
        selectedIPSW = nil
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let result = Shell.run(executable, arguments: ["--ipsw-info", url.path], timeout: 90)
            let summary = result.output.isEmpty ? "Не вдалося прочитати IPSW." : String(result.output.prefix(5_000))
            DispatchQueue.main.async {
                self?.selectedIPSW = IPSWSelection(url: url, isVerified: result.succeeded, summary: summary)
                self?.firmwareStatus = result.succeeded
                    ? "IPSW перевірено локально. Перед запуском переконайтеся, що Apple ще підписує цю версію для пристрою."
                    : "IPSW не пройшов перевірку: \(summary)"
            }
        }
    }

    // MARK: - Operation runner

    func cancelCurrentOperation() {
        guard operation.isRunning else { return }
        operation.status = "Надсилається запит на скасування…"
        operationProcess?.interrupt()
    }

    private func beginOperation(
        kind: DeviceOperationKind,
        executable: String,
        arguments: [String],
        successMessage: String,
        completion: ((Bool) -> Void)? = nil
    ) {
        guard !operation.isRunning else { return }
        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.standardOutput = pipe
        process.standardError = pipe

        operation = DeviceOperationState(kind: kind, isRunning: true, status: "Запущено: \(kind.rawValue)", log: "", startedAt: Date())
        isBackingUp = kind == .backup
        backupStatus = kind == .backup ? "Створюється локальний бекап… Не від’єднуйте пристрій." : backupStatus
        operationProcess = process
        operationPipe = pipe

        pipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty, let text = String(data: data, encoding: .utf8) else { return }
            DispatchQueue.main.async { self?.appendOperationLog(text) }
        }
        process.terminationHandler = { [weak self] process in
            DispatchQueue.main.async {
                guard let self else { return }
                self.operationPipe?.fileHandleForReading.readabilityHandler = nil
                self.operation.isRunning = false
                self.operation.finishedAt = Date()
                self.operation.exitCode = process.terminationStatus
                self.operation.status = process.terminationStatus == 0 ? successMessage : "Операція не завершилася (код \(process.terminationStatus)). Перегляньте журнал."
                self.isBackingUp = false
                if kind == .backup { self.backupStatus = self.operation.status }
                self.operationProcess = nil
                self.operationPipe = nil
                completion?(process.terminationStatus == 0)
            }
        }
        do {
            try process.run()
        } catch {
            operation.isRunning = false
            operation.finishedAt = Date()
            operation.exitCode = -1
            operation.status = "Не вдалося запустити \(kind.rawValue): \(error.localizedDescription)"
            operationProcess = nil
            operationPipe = nil
        }
    }

    private func appendOperationLog(_ text: String) {
        let sanitized = text.replacingOccurrences(of: "\u{0}", with: "")
        operation.log += sanitized
        if operation.log.count > 18_000 {
            operation.log = String(operation.log.suffix(18_000))
        }
    }

    // MARK: - Local data and helpers

    private func loadBackups(for deviceID: String) {
        guard Self.isValidDeviceID(deviceID) else { backups = []; return }
        let manager = FileManager.default
        let keys: Set<URLResourceKey> = [.isDirectoryKey, .creationDateKey, .contentModificationDateKey]
        let found = rememberedBackupRoots().flatMap { rootURL -> [LocalDeviceBackup] in
            let folder = rootURL.appendingPathComponent("MacHealth Backups", isDirectory: true).appendingPathComponent(deviceID, isDirectory: true)
            guard let folders = try? manager.contentsOfDirectory(at: folder, includingPropertiesForKeys: Array(keys), options: [.skipsHiddenFiles]) else { return [] }
            return folders.compactMap { url in
                guard let values = try? url.resourceValues(forKeys: keys), values.isDirectory == true else { return nil }
                return LocalDeviceBackup(url: url, createdAt: values.creationDate ?? values.contentModificationDate ?? .distantPast)
            }
        }
        backups = found.sorted { $0.createdAt > $1.createdAt }
    }

    private func rememberBackupRoot(_ rootURL: URL) {
        let path = rootURL.standardizedFileURL.path
        var paths = UserDefaults.standard.stringArray(forKey: backupRootsKey) ?? []
        if !paths.contains(path) {
            paths.append(path)
            UserDefaults.standard.set(paths, forKey: backupRootsKey)
        }
    }

    private func rememberedBackupRoots() -> [URL] {
        (UserDefaults.standard.stringArray(forKey: backupRootsKey) ?? []).map { URL(fileURLWithPath: $0, isDirectory: true) }
    }

    private func checkTrust(deviceID: String) -> DeviceTrustState {
        guard let executable = toolPath(for: "idevicepair") else { return .unavailable }
        return Shell.run(executable, arguments: ["-u", deviceID, "validate"]).succeeded ? .trusted : .needsTrust
    }

    private func hasTool(_ name: String) -> Bool { availableTools.contains(name) }

    private func toolPath(for tool: String) -> String? {
        let pathDirectories = Foundation.ProcessInfo.processInfo.environment["PATH"]?.split(separator: ":").map(String.init) ?? []
        for directory in ["/opt/homebrew/bin", "/usr/local/bin", "/usr/bin"] + pathDirectories {
            let path = "\(directory)/\(tool)"
            if FileManager.default.isExecutableFile(atPath: path) { return path }
        }
        return nil
    }

    private func tool(_ name: String) -> String { toolPath(for: name) ?? name }

    private func formatBytes(_ string: String) -> String {
        guard let bytes = Double(string) else { return "—" }
        return bytes >= 1_073_741_824 ? String(format: "%.1f ГБ", bytes / 1_073_741_824) : String(format: "%.0f МБ", bytes / 1_048_576)
    }

    private func translateActivation(_ state: String) -> String {
        switch state.lowercased() {
        case "activated": return "Активовано"
        case "unactivated": return "Не активовано"
        default: return state.orDash
        }
    }

    private static func parseApps(from text: String) -> [ManagedApp] {
        guard let data = text.data(using: .utf8),
              let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) else {
            return parseTextApps(text)
        }
        var apps: [ManagedApp] = []
        collectApps(from: plist, keyHint: nil, into: &apps)
        return Array(Set(apps)).sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private static func collectApps(from value: Any, keyHint: String?, into apps: inout [ManagedApp]) {
        if let dictionary = value as? [String: Any] {
            let identifier = dictionary["CFBundleIdentifier"] as? String ?? keyHint
            if let identifier, identifier.contains(".") {
                let name = (dictionary["CFBundleDisplayName"] as? String) ?? (dictionary["CFBundleName"] as? String) ?? identifier
                let version = (dictionary["CFBundleShortVersionString"] as? String) ?? "—"
                apps.append(ManagedApp(bundleIdentifier: identifier, name: name, version: version))
            }
            for (key, nested) in dictionary { collectApps(from: nested, keyHint: key, into: &apps) }
        } else if let array = value as? [Any] {
            for nested in array { collectApps(from: nested, keyHint: nil, into: &apps) }
        }
    }

    private static func parseTextApps(_ text: String) -> [ManagedApp] {
        text.components(separatedBy: .newlines).compactMap { line in
            let parts = line.split(maxSplits: 1, whereSeparator: { $0 == " " || $0 == "\t" })
            guard let identifier = parts.first.map(String.init), identifier.contains(".") else { return nil }
            let name = parts.count > 1 ? String(parts[1]).trimmingCharacters(in: CharacterSet(charactersIn: " -")) : identifier
            return ManagedApp(bundleIdentifier: identifier, name: name, version: "—")
        }
    }

    private static func isValidDeviceID(_ value: String) -> Bool {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return (16...64).contains(trimmed.count) && trimmed.unicodeScalars.allSatisfy { CharacterSet.alphanumerics.contains($0) || $0 == "-" }
    }
}
