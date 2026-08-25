import SwiftUI
import AppKit

struct iPhoneMainView: View {
    @ObservedObject var service: iPhoneService
    @State private var showBackupConfirmation = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                HStack {
                    Text("Діагностика iPhone")
                        .font(.largeTitle.bold())
                    Spacer()
                    Button(action: { service.checkAndConnect() }) {
                        Label("Оновити", systemImage: "arrow.clockwise")
                    }
                    .buttonStyle(.borderedProminent)
                }
                
                if service.isLoading {
                    VStack(spacing: 12) {
                        ProgressView()
                            .scaleEffect(1.3)
                        Text("Пошук iPhone...")
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, minHeight: 200)
                } else if !service.phone.isConnected {
                    notConnectedView
                } else {
                    connectedView
                }
            }
            .padding(24)
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear { service.checkAndConnect() }
    }
    
    private var notConnectedView: some View {
        VStack(spacing: 20) {
            Image(systemName: "iphone.slash")
                .font(.system(size: 56))
                .foregroundStyle(.secondary)
            
            Text("iPhone не підключено")
                .font(.title2.bold())
            
            if let error = service.errorMessage {
                Text(error)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            VStack(alignment: .leading, spacing: 10) {
                Label("Підключіть iPhone через USB-кабель", systemImage: "1.circle.fill")
                Label("Розблокуйте iPhone", systemImage: "2.circle.fill")
                Label("Натисніть «Довіряти» на iPhone", systemImage: "3.circle.fill")
                Label("Натисніть «Оновити» вище", systemImage: "4.circle.fill")
            }
            .font(.subheadline)
            .padding(20)
            .background(RoundedRectangle(cornerRadius: 12).fill(.blue.opacity(0.05)))
            
            if !service.hasLibimobiledevice {
                VStack(spacing: 8) {
                    Text("💡 Для повної діагностики:")
                        .font(.headline)
                    HStack {
                        Text("brew install libimobiledevice")
                            .font(.system(.body, design: .monospaced))
                            .padding(8)
                            .background(RoundedRectangle(cornerRadius: 6).fill(.gray.opacity(0.1)))
                        Button(action: {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString("brew install libimobiledevice", forType: .string)
                        }) {
                            Image(systemName: "doc.on.doc")
                        }
                        .buttonStyle(.bordered)
                    }
                }
                .padding(16)
                .background(RoundedRectangle(cornerRadius: 12).fill(.background))
                .shadow(color: .black.opacity(0.05), radius: 4)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 400)
    }
    
    private var connectedView: some View {
        VStack(spacing: 16) {
            // Status
            HStack(spacing: 12) {
                Image(systemName: "iphone")
                    .font(.system(size: 32))
                    .foregroundStyle(.green)
                VStack(alignment: .leading) {
                    Text(service.phone.deviceName)
                        .font(.title3.bold())
                    Text(service.phone.modelName)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Label("Підключено", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .font(.subheadline.bold())
            }
            .sectionCard()
            
            if let error = service.errorMessage {
                HStack {
                    Image(systemName: "info.circle.fill")
                        .foregroundStyle(.orange)
                    Text(error)
                        .font(.caption)
                }
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 8).fill(.orange.opacity(0.05)))
            }
            
            // Info Cards
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Інформація", systemImage: "info.circle")
                        .font(.headline)
                    Divider()
                    InfoRow(label: "Серійний №", value: service.phone.serialNumber)
                    InfoRow(label: "IMEI", value: service.phone.imei)
                    InfoRow(label: "iOS", value: service.phone.iosVersion)
                    InfoRow(label: "Збірка", value: service.phone.buildVersion)
                    InfoRow(label: "Wi-Fi MAC", value: service.phone.wifiMAC)
                    InfoRow(label: "BT MAC", value: service.phone.bluetoothMAC)
                    InfoRow(label: "Активація", value: service.phone.activationStatus)
                }
                .cardStyle()
                
                VStack(alignment: .leading, spacing: 8) {
                    Label("Батарея та пам'ять", systemImage: "battery.75percent")
                        .font(.headline)
                    Divider()
                    if let batteryLevel = service.phone.batteryLevel {
                        InfoRow(label: "Заряд", value: "\(batteryLevel)%")
                    }
                    InfoRow(label: "Здоров'я", value: service.phone.batteryHealthDisplay)
                    InfoRow(label: "Всього", value: service.phone.totalStorage)
                    InfoRow(label: "Вільно", value: service.phone.freeStorage)
                    
                    if let healthLevel = service.phone.batteryHealthLevel {
                        Divider()
                        HStack {
                            Image(systemName: healthLevel.icon)
                                .foregroundStyle(Color.statusColor(healthLevel))
                            Text(healthLevel.rawValue)
                                .font(.caption.bold())
                                .foregroundStyle(Color.statusColor(healthLevel))
                        }
                    } else {
                        Text("iOS не надає Maximum Capacity через стандартне USB-з’єднання.")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .cardStyle()
            }

            VStack(alignment: .leading, spacing: 10) {
                Label("Доступ і можливості", systemImage: "checkmark.shield")
                    .font(.headline)
                Divider()
                HStack(spacing: 8) {
                    Image(systemName: service.phone.trustState.icon)
                        .foregroundStyle(Color.statusColor(service.phone.trustState.level))
                    Text(service.phone.trustState.rawValue)
                        .font(.subheadline.weight(.medium))
                    Spacer()
                    Text(service.phone.connection)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if service.phone.deviceID != "—" {
                    HStack {
                        Text("UDID")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(service.phone.deviceID)
                            .font(.system(.caption, design: .monospaced))
                            .textSelection(.enabled)
                        Button {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(service.phone.deviceID, forType: .string)
                        } label: {
                            Image(systemName: "doc.on.doc")
                        }
                        .buttonStyle(.borderless)
                        .help("Копіювати UDID")
                    }
                }
                HStack(spacing: 12) {
                    CapabilityPill(title: "Дані пристрою", available: service.phone.trustState == .trusted)
                    CapabilityPill(title: "Локальний бекап", available: service.canCreateBackup)
                    CapabilityPill(title: "Файловий обмін", available: service.phone.trustState == .trusted)
                }
                HStack {
                    Button {
                        showBackupConfirmation = true
                    } label: {
                        Label(service.isBackingUp ? "Створення бекапу…" : "Створити локальний бекап", systemImage: "externaldrive.badge.plus")
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!service.canCreateBackup || service.isBackingUp)

                    if service.isBackingUp {
                        ProgressView()
                            .controlSize(.small)
                    }
                }
                if let backupStatus = service.backupStatus {
                    Text(backupStatus)
                        .font(.caption)
                        .foregroundStyle(service.isBackingUp ? .secondary : .primary)
                }
                Text("Файловий обмін доступний лише для застосунків iOS, які підтримують Apple File Sharing. Дані не надсилаються у хмару.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .cardStyle()
        }
        .alert("Створити локальний бекап?", isPresented: $showBackupConfirmation) {
            Button("Скасувати", role: .cancel) {}
            Button("Обрати папку й продовжити") { service.chooseBackupDestination() }
        } message: {
            Text("На iPhone може з’явитися запит на пароль бекапу. Оберіть папку з достатнім вільним місцем і не від’єднуйте пристрій до завершення.")
        }
    }
}

private struct CapabilityPill: View {
    let title: String
    let available: Bool

    var body: some View {
        Label(title, systemImage: available ? "checkmark.circle.fill" : "minus.circle")
            .font(.caption)
            .foregroundStyle(available ? .green : .secondary)
            .padding(.horizontal, 9)
            .padding(.vertical, 6)
            .background(Capsule().fill((available ? Color.green : Color.gray).opacity(0.1)))
    }
}
