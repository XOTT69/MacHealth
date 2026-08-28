import SwiftUI
import AppKit

struct iPhoneMainView: View {
    @ObservedObject var service: iPhoneService
    @State private var showBackupConfirmation = false
    @State private var backupToRestore: LocalDeviceBackup?
    @State private var appToUninstall: ManagedApp?
    @State private var showUpdateConfirmation = false
    @State private var showEraseSheet = false
    @State private var erasePhrase = ""

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                header
                if service.isLoading {
                    ProgressView("Пошук iPhone або iPad…")
                        .frame(maxWidth: .infinity, minHeight: 260)
                } else if !service.phone.isConnected {
                    notConnectedView
                } else {
                    connectedView
                }
            }
            .padding(28)
            .frame(maxWidth: 1120)
            .frame(maxWidth: .infinity)
        }
        .background(Color(nsColor: .windowBackgroundColor).ignoresSafeArea())
        .onAppear { service.checkAndConnect() }
        .alert("Створити локальний бекап?", isPresented: $showBackupConfirmation) {
            Button("Скасувати", role: .cancel) {}
            Button("Обрати папку й продовжити") { service.chooseBackupDestination() }
        } message: {
            Text("Бекап зберігається тільки у вибраній вами папці на Mac. Не від’єднуйте пристрій до завершення.")
        }
        .alert("Відновити цей бекап?", isPresented: Binding(get: { backupToRestore != nil }, set: { if !$0 { backupToRestore = nil } })) {
            Button("Скасувати", role: .cancel) { backupToRestore = nil }
            Button("Відновити", role: .destructive) {
                if let backupToRestore { service.restoreBackup(backupToRestore) }
                backupToRestore = nil
            }
        } message: {
            Text("Дані та налаштування на пристрої можуть бути замінені станом із бекапу. Переконайтеся, що обрано правильний пристрій і резервну копію.")
        }
        .alert("Видалити програму?", isPresented: Binding(get: { appToUninstall != nil }, set: { if !$0 { appToUninstall = nil } })) {
            Button("Скасувати", role: .cancel) { appToUninstall = nil }
            Button("Видалити", role: .destructive) {
                if let appToUninstall { service.uninstallApp(appToUninstall) }
                appToUninstall = nil
            }
        } message: {
            Text("Буде видалено «\(appToUninstall?.name ?? "")» і її локальні дані на пристрої.")
        }
        .alert("Оновити iOS/iPadOS?", isPresented: $showUpdateConfirmation) {
            Button("Скасувати", role: .cancel) {}
            Button("Почати оновлення") { service.startFirmwareRestore(erasing: false) }
        } message: {
            Text("MacHealth використає перевірений локальний IPSW і спробує зберегти дані. Apple може вимагати підписану версію; створіть бекап перед продовженням.")
        }
        .sheet(isPresented: $showEraseSheet) {
            eraseConfirmationSheet
        }
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 5) {
                Text("Device Hub")
                    .font(.largeTitle.bold())
                Text("Керування власним iPhone та iPad через локальне USB-з’єднання")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button { service.checkAndConnect() } label: {
                Label("Оновити", systemImage: "arrow.clockwise")
            }
            .buttonStyle(.borderedProminent)
            .disabled(service.isLoading || service.operation.isRunning)
        }
    }

    private var notConnectedView: some View {
        VStack(spacing: 18) {
            Image(systemName: "iphone.slash")
                .font(.system(size: 56))
                .foregroundStyle(.secondary)
            Text("Пристрій не готовий")
                .font(.title2.bold())
            Text(service.errorMessage ?? "Підключіть iPhone або iPad через USB.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 10) {
                Label("Підключіть пристрій кабелем", systemImage: "1.circle.fill")
                Label("Розблокуйте його", systemImage: "2.circle.fill")
                Label("Натисніть «Довіряти»", systemImage: "3.circle.fill")
                Label("Поверніться сюди та натисніть «Оновити»", systemImage: "4.circle.fill")
            }
            .font(.subheadline)
            .padding(18)
            .background(RoundedRectangle(cornerRadius: 14).fill(.blue.opacity(0.07)))

            if !service.hasLibimobiledevice {
                installHelp(command: "brew install libimobiledevice", title: "Базові дані та бекапи")
            }
        }
        .frame(maxWidth: .infinity, minHeight: 420)
    }

    private var connectedView: some View {
        VStack(spacing: 16) {
            deviceStatusCard
            if let error = service.errorMessage { notice(error, color: .orange, icon: "exclamationmark.triangle.fill") }
            deviceInformation
            capabilityCard
            backupsCard
            applicationsCard
            firmwareCard
            operationCard
        }
    }

    private var deviceStatusCard: some View {
        HStack(spacing: 14) {
            Image(systemName: "iphone")
                .font(.system(size: 34))
                .foregroundStyle(.blue)
                .frame(width: 58, height: 58)
                .background(Circle().fill(.blue.opacity(0.12)))
            VStack(alignment: .leading, spacing: 3) {
                Text(service.phone.deviceName).font(.title3.bold())
                Text(service.phone.modelName).font(.subheadline).foregroundStyle(.secondary)
                Text(service.phone.connection).font(.caption).foregroundStyle(.tertiary)
            }
            Spacer()
            Label(service.phone.trustState.rawValue, systemImage: service.phone.trustState.icon)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.statusColor(service.phone.trustState.level))
        }
        .sectionCard()
    }

    private var deviceInformation: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Label("Пристрій", systemImage: "info.circle").font(.headline)
                Divider()
                InfoRow(label: "Серійний №", value: service.phone.serialNumber)
                InfoRow(label: "IMEI", value: service.phone.imei)
                InfoRow(label: "iOS / iPadOS", value: service.phone.iosVersion)
                InfoRow(label: "Збірка", value: service.phone.buildVersion)
                InfoRow(label: "Активація", value: service.phone.activationStatus)
                if service.phone.deviceID != "—" {
                    HStack {
                        Text("UDID").font(.caption).foregroundStyle(.secondary)
                        Spacer()
                        Text(service.phone.deviceID).font(.system(.caption, design: .monospaced)).textSelection(.enabled)
                        Button { copy(service.phone.deviceID) } label: { Image(systemName: "doc.on.doc") }
                            .buttonStyle(.borderless)
                    }
                }
            }
            .cardStyle()

            VStack(alignment: .leading, spacing: 8) {
                Label("Батарея та сховище", systemImage: "battery.75percent").font(.headline)
                Divider()
                InfoRow(label: "Заряд", value: service.phone.batteryLevel.map { "\($0)%" } ?? "Недоступно")
                InfoRow(label: "Maximum Capacity", value: service.phone.batteryHealthDisplay)
                InfoRow(label: "Всього", value: service.phone.totalStorage)
                InfoRow(label: "Вільно", value: service.phone.freeStorage)
                Text("iOS не надає Maximum Capacity через стандартний USB-протокол; значення не підміняється.")
                    .font(.caption2).foregroundStyle(.secondary)
            }
            .cardStyle()
        }
    }

    private var capabilityCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Готовність інструментів", systemImage: "checkmark.shield").font(.headline)
            Divider()
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                toolPill("Бекапи", tool: "idevicebackup2")
                toolPill("Програми", tool: "ideviceinstaller")
                toolPill("IPSW", tool: "idevicerestore")
            }
            if !service.hasLibimobiledevice {
                installHelp(command: "brew install libimobiledevice", title: "Встановити базові інструменти")
            }
            Text("IPSW і керування програмами потребують додаткових сумісних утиліт. Наявність показана вище; MacHealth не завантажує та не запускає їх самостійно.")
                .font(.caption).foregroundStyle(.secondary)
        }
        .cardStyle()
    }

    private var backupsCard: some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack {
                Label("Локальні бекапи", systemImage: "externaldrive.badge.plus").font(.headline)
                Spacer()
                Button { showBackupConfirmation = true } label: {
                    Label("Створити", systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
                .disabled(!service.canCreateBackup || service.operation.isRunning)
            }
            Divider()
            if let status = service.backupStatus { Text(status).font(.caption).foregroundStyle(.secondary) }
            if service.backups.isEmpty {
                Text("У вибраних папках ще немає бекапів для цього UDID.")
                    .font(.subheadline).foregroundStyle(.secondary)
            } else {
                ForEach(service.backups) { backup in
                    HStack {
                        Image(systemName: "externaldrive.fill").foregroundStyle(.blue)
                        VStack(alignment: .leading) {
                            Text(backup.title).font(.subheadline.weight(.medium))
                            Text(backup.url.path).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                        }
                        Spacer()
                        Button("Finder") { NSWorkspace.shared.activateFileViewerSelecting([backup.url]) }
                            .buttonStyle(.borderless)
                        Button("Відновити") { backupToRestore = backup }
                            .buttonStyle(.bordered)
                            .disabled(!service.canRestoreBackup || service.operation.isRunning)
                    }
                }
            }
            Text("Відновлення може замінити дані на пристрої. Перед ним створіть свіжий бекап.")
                .font(.caption).foregroundStyle(.orange)
        }
        .cardStyle()
    }

    private var applicationsCard: some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack {
                Label("Програми", systemImage: "square.grid.2x2").font(.headline)
                Spacer()
                Button { service.refreshInstalledApps() } label: { Image(systemName: "arrow.clockwise") }
                    .buttonStyle(.borderless)
                    .disabled(!service.canManageApps || service.isLoadingApps || service.operation.isRunning)
                Button { service.chooseIPAForInstallation() } label: { Label("Обрати IPA", systemImage: "square.and.arrow.down") }
                    .buttonStyle(.bordered)
                    .disabled(!service.canManageApps || service.operation.isRunning)
            }
            Divider()
            if !service.canManageApps {
                Text("Потрібен довірений пристрій і встановлений ideviceinstaller.")
                    .font(.subheadline).foregroundStyle(.secondary)
            } else {
                if let ipa = service.selectedIPA {
                    HStack {
                        Image(systemName: "shippingbox").foregroundStyle(.blue)
                        Text(ipa.lastPathComponent).lineLimit(1)
                        Spacer()
                        Button("Встановити") { service.installSelectedIPA() }
                            .buttonStyle(.borderedProminent)
                            .disabled(service.operation.isRunning)
                    }
                }
                if service.isLoadingApps {
                    ProgressView("Читаємо список програм…")
                } else if service.installedApps.isEmpty {
                    Text("Список програм ще не отримано або пристрій не повернув user-apps.")
                        .font(.subheadline).foregroundStyle(.secondary)
                } else {
                    ForEach(service.installedApps) { app in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(app.name).font(.subheadline.weight(.medium))
                                Text("\(app.bundleIdentifier) • \(app.version)").font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button(role: .destructive) { appToUninstall = app } label: { Image(systemName: "trash") }
                                .buttonStyle(.borderless)
                                .disabled(service.operation.isRunning)
                        }
                    }
                }
                Text("Встановлюються тільки IPA з дійсним підписом для цього пристрою. MacHealth не підписує й не модифікує пакети.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .cardStyle()
    }

    private var firmwareCard: some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack {
                Label("Відновлення IPSW", systemImage: "arrow.triangle.2.circlepath").font(.headline)
                Spacer()
                Button { service.chooseIPSW() } label: { Label("Обрати IPSW", systemImage: "doc.zipper") }
                    .buttonStyle(.bordered)
                    .disabled(!service.availableTools.contains("idevicerestore") || service.operation.isRunning)
            }
            Divider()
            if !service.availableTools.contains("idevicerestore") {
                Text("idevicerestore не знайдено. Ця утиліта потрібна для роботи з офіційними IPSW.")
                    .font(.subheadline).foregroundStyle(.secondary)
            } else {
                if let ipsw = service.selectedIPSW {
                    VStack(alignment: .leading, spacing: 7) {
                        Label(ipsw.isVerified ? "IPSW пройшов локальну перевірку" : "IPSW не пройшов перевірку", systemImage: ipsw.isVerified ? "checkmark.seal.fill" : "xmark.seal.fill")
                            .foregroundStyle(ipsw.isVerified ? .green : .red)
                        Text(ipsw.url.lastPathComponent).font(.subheadline.weight(.medium))
                        Text(ipsw.summary).font(.caption2).foregroundStyle(.secondary).lineLimit(5).textSelection(.enabled)
                    }
                    .padding(10)
                    .background(RoundedRectangle(cornerRadius: 10).fill(.gray.opacity(0.07)))
                }
                if let status = service.firmwareStatus { Text(status).font(.caption).foregroundStyle(.secondary) }
                HStack {
                    Button("Оновити без стирання") { showUpdateConfirmation = true }
                        .buttonStyle(.borderedProminent)
                        .disabled(!service.canRestoreFirmware || service.operation.isRunning)
                    Button("Стерти й відновити", role: .destructive) { erasePhrase = ""; showEraseSheet = true }
                        .buttonStyle(.bordered)
                        .disabled(!service.canRestoreFirmware || service.operation.isRunning)
                }
                Text("Оновлення намагається зберегти дані, але це не гарантія. Повне відновлення безповоротно стирає дані. Використовуйте лише IPSW, який Apple підписує для моделі пристрою.")
                    .font(.caption).foregroundStyle(.orange)
            }
        }
        .cardStyle()
    }

    @ViewBuilder
    private var operationCard: some View {
        if service.operation.kind != nil {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Label(service.operation.kind?.rawValue ?? "Операція", systemImage: service.operation.kind?.icon ?? "terminal")
                        .font(.headline)
                    Spacer()
                    if service.operation.isRunning {
                        ProgressView().controlSize(.small)
                        Button("Скасувати") { service.cancelCurrentOperation() }.buttonStyle(.bordered)
                    } else if service.operation.hasResult {
                        Label(service.operation.succeeded ? "Успішно" : "Потрібна перевірка", systemImage: service.operation.succeeded ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundStyle(service.operation.succeeded ? .green : .red)
                            .font(.caption.bold())
                    }
                }
                Text(service.operation.status).font(.subheadline).foregroundStyle(.secondary)
                if !service.operation.log.isEmpty {
                    Text(service.operation.log)
                        .font(.system(.caption2, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .frame(maxHeight: 180, alignment: .top)
                        .padding(10)
                        .background(RoundedRectangle(cornerRadius: 8).fill(.black.opacity(0.06)))
                }
            }
            .cardStyle()
        }
    }

    private var eraseConfirmationSheet: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("Повне відновлення IPSW", systemImage: "exclamationmark.triangle.fill")
                .font(.title2.bold()).foregroundStyle(.red)
            Text("Ця дія видалить усі дані з «\(service.phone.deviceName)». Переконайтеся, що у вас є актуальний бекап і пристрій підключений кабелем.")
            Text("Введіть ERASE для підтвердження:").font(.subheadline.weight(.medium))
            TextField("ERASE", text: $erasePhrase).textFieldStyle(.roundedBorder)
            HStack {
                Spacer()
                Button("Скасувати") { showEraseSheet = false }
                Button("Стерти й відновити", role: .destructive) {
                    showEraseSheet = false
                    service.startFirmwareRestore(erasing: true)
                }
                .disabled(erasePhrase != "ERASE")
            }
        }
        .padding(26)
        .frame(width: 480)
    }

    private func toolPill(_ title: String, tool: String) -> some View {
        let available = service.availableTools.contains(tool)
        return Label(title, systemImage: available ? "checkmark.circle.fill" : "minus.circle")
            .font(.caption)
            .foregroundStyle(available ? .green : .secondary)
            .padding(.horizontal, 9).padding(.vertical, 7)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 8).fill((available ? Color.green : Color.gray).opacity(0.09)))
    }

    private func installHelp(command: String, title: String) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.caption.weight(.medium))
                Text(command).font(.system(.caption, design: .monospaced))
            }
            Spacer()
            Button { copy(command) } label: { Image(systemName: "doc.on.doc") }
                .buttonStyle(.borderless)
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 9).fill(.gray.opacity(0.08)))
    }

    private func notice(_ text: String, color: Color, icon: String) -> some View {
        Label(text, systemImage: icon)
            .font(.subheadline)
            .foregroundStyle(color)
            .padding(13)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 12).fill(color.opacity(0.08)))
    }

    private func copy(_ string: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(string, forType: .string)
    }
}
