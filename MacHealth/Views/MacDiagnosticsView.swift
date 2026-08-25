import SwiftUI

struct MacDiagnosticsView: View {
    @StateObject private var service = MacDiagnosticService()
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Заголовок
                headerSection
                
                if service.isLoading {
                    loadingView
                } else {
                    // Загальний стан
                    overallHealthCard
                    
                    // Інформація про Mac
                    macInfoCard
                    
                    // Сітка діагностики
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 16) {
                        batteryCard
                        cpuCard
                        ramCard
                        storageCard
                        networkCard
                        displayCard
                    }
                }
            }
            .padding(24)
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear {
            service.runFullDiagnostics()
        }
    }
    
    // MARK: - Header
    
    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Діагностика MacBook")
                    .font(.largeTitle.bold())
                Text("Повний аналіз стану вашого комп'ютера")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            Button(action: { service.runFullDiagnostics() }) {
                Label("Оновити", systemImage: "arrow.clockwise")
                    .font(.headline)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
    }
    
    // MARK: - Loading
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
            Text("Виконується діагностика...")
                .font(.headline)
                .foregroundStyle(.secondary)
            Text("Це може зайняти кілька секунд")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, minHeight: 300)
    }
    
    // MARK: - Overall Health
    
    private var overallHealthCard: some View {
        HStack(spacing: 16) {
            Image(systemName: service.overallHealth.icon)
                .font(.system(size: 40))
                .foregroundStyle(healthColor(service.overallHealth))
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Загальний стан системи")
                    .font(.headline)
                Text(service.overallHealth.label)
                    .font(.title2.bold())
                    .foregroundStyle(healthColor(service.overallHealth))
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text(service.macInfo.modelName)
                    .font(.subheadline.bold())
                Text(service.macInfo.osVersion)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(20)
        .background(RoundedRectangle(cornerRadius: 16).fill(.background))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(healthColor(service.overallHealth).opacity(0.3), lineWidth: 2))
        .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
    }
    
    // MARK: - Mac Info Card
    
    private var macInfoCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Інформація про систему", systemImage: "desktopcomputer")
                .font(.headline)
            
            Divider()
            
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                infoItem(title: "Модель", value: service.macInfo.modelName)
                infoItem(title: "Ідентифікатор", value: service.macInfo.modelIdentifier)
                infoItem(title: "Серійний номер", value: service.macInfo.serialNumber)
                infoItem(title: "Процесор", value: service.macInfo.chipInfo)
                infoItem(title: "Час роботи", value: service.macInfo.uptime)
                infoItem(title: "macOS", value: service.macInfo.osVersion)
            }
        }
        .padding(20)
        .background(RoundedRectangle(cornerRadius: 16).fill(.background))
        .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
    }
    
    // MARK: - Battery Card
    
    private var batteryCard: some View {
        DiagnosticCard(
            title: "Батарея",
            icon: "battery.75percent",
            status: service.batteryInfo.healthStatus
        ) {
            VStack(alignment: .leading, spacing: 8) {
                ProgressBarView(
                    value: service.batteryInfo.healthPercentage / 100,
                    color: healthColor(service.batteryInfo.healthStatus)
                )
                
                HStack {
                    Text("Здоров'я:")
                        .foregroundStyle(.secondary)
                    Text("\(String(format: "%.0f", service.batteryInfo.healthPercentage))%")
                        .bold()
                }
                .font(.caption)
                
                infoRow(label: "Стан", value: service.batteryInfo.condition)
                infoRow(label: "Цикли", value: "\(service.batteryInfo.cycleCount)")
                infoRow(label: "Температура", value: "\(String(format: "%.1f", service.batteryInfo.temperature))°C")
                infoRow(label: "Зарядка", value: service.batteryInfo.isCharging ? "⚡ Так" : "Ні")
            }
        }
    }
    
    // MARK: - CPU Card
    
    private var cpuCard: some View {
        DiagnosticCard(
            title: "Процесор",
            icon: "cpu",
            status: service.cpuInfo.usageStatus
        ) {
            VStack(alignment: .leading, spacing: 8) {
                ProgressBarView(
                    value: service.cpuInfo.currentUsage / 100,
                    color: healthColor(service.cpuInfo.usageStatus)
                )
                
                HStack {
                    Text("Навантаження:")
                        .foregroundStyle(.secondary)
                    Text("\(String(format: "%.0f", service.cpuInfo.currentUsage))%")
                        .bold()
                }
                .font(.caption)
                
                infoRow(label: "Модель", value: service.cpuInfo.modelName)
                infoRow(label: "Ядра", value: "\(service.cpuInfo.coreCount)")
                if service.cpuInfo.temperature > 0 {
                    infoRow(label: "Температура", value: "\(String(format: "%.0f", service.cpuInfo.temperature))°C")
                }
            }
        }
    }
    
    // MARK: - RAM Card
    
    private var ramCard: some View {
        DiagnosticCard(
            title: "Оперативна пам'ять",
            icon: "memorychip",
            status: service.ramInfo.usageStatus
        ) {
            VStack(alignment: .leading, spacing: 8) {
                ProgressBarView(
                    value: service.ramInfo.usagePercentage / 100,
                    color: healthColor(service.ramInfo.usageStatus)
                )
                
                HStack {
                    Text("Використано:")
                        .foregroundStyle(.secondary)
                    Text("\(String(format: "%.1f", service.ramInfo.usedGB)) / \(String(format: "%.0f", service.ramInfo.totalGB)) ГБ")
                        .bold()
                }
                .font(.caption)
                
                infoRow(label: "Тип", value: service.ramInfo.type)
                infoRow(label: "Вільно", value: "\(String(format: "%.1f", service.ramInfo.freeGB)) ГБ")
            }
        }
    }
    
    // MARK: - Storage Card
    
    private var storageCard: some View {
        DiagnosticCard(
            title: "Сховище",
            icon: "internaldrive",
            status: service.storageInfo.usageStatus
        ) {
            VStack(alignment: .leading, spacing: 8) {
                ProgressBarView(
                    value: service.storageInfo.usagePercentage / 100,
                    color: healthColor(service.storageInfo.usageStatus)
                )
                
                HStack {
                    Text("Використано:")
                        .foregroundStyle(.secondary)
                    Text("\(String(format: "%.0f", service.storageInfo.usedGB)) / \(String(format: "%.0f", service.storageInfo.totalGB)) ГБ")
                        .bold()
                }
                .font(.caption)
                
                infoRow(label: "Тип", value: service.storageInfo.type)
                infoRow(label: "SMART", value: service.storageInfo.smartStatus)
                infoRow(label: "Файлова с-ма", value: service.storageInfo.fileSystem)
            }
        }
    }
    
    // MARK: - Network Card
    
    private var networkCard: some View {
        DiagnosticCard(
            title: "Мережа",
            icon: "wifi",
            status: .good
        ) {
            VStack(alignment: .leading, spacing: 8) {
                infoRow(label: "Wi-Fi", value: service.networkInfo.wifiName)
                infoRow(label: "IP", value: service.networkInfo.localIP)
                infoRow(label: "MAC", value: service.networkInfo.wifiMAC)
                infoRow(label: "Bluetooth", value: service.networkInfo.bluetoothVersion)
            }
        }
    }
    
    // MARK: - Display Card
    
    private var displayCard: some View {
        DiagnosticCard(
            title: "Дисплей",
            icon: "display",
            status: .good
        ) {
            VStack(alignment: .leading, spacing: 8) {
                infoRow(label: "Назва", value: service.displayInfo.name)
                infoRow(label: "Роздільна зд.", value: service.displayInfo.resolution)
                infoRow(label: "Тип", value: service.displayInfo.displayType)
            }
        }
    }
    
    // MARK: - Helper Views
    
    private func infoItem(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.caption)
                .bold()
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 4)
    }
    
    private func infoRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.caption)
                .bold()
                .lineLimit(1)
        }
    }
    
    private func healthColor(_ status: HealthStatus) -> Color {
        switch status {
        case .good: return .green
        case .warning: return .orange
        case .critical: return .red
        }
    }
}

// MARK: - Diagnostic Card Component

struct DiagnosticCard<Content: View>: View {
    let title: String
    let icon: String
    let status: HealthStatus
    @ViewBuilder let content: Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(.blue)
                Text(title)
                    .font(.headline)
                Spacer()
                Image(systemName: status.icon)
                    .foregroundStyle(statusColor)
            }
            
            Divider()
            
            content
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 12).fill(.background))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.gray.opacity(0.1), lineWidth: 1))
        .shadow(color: .black.opacity(0.03), radius: 4, y: 2)
    }
    
    private var statusColor: Color {
        switch status {
        case .good: return .green
        case .warning: return .orange
        case .critical: return .red
        }
    }
}

// MARK: - Progress Bar

struct ProgressBarView: View {
    let value: Double
    let color: Color
    
    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.gray.opacity(0.15))
                    .frame(height: 8)
                
                RoundedRectangle(cornerRadius: 4)
                    .fill(color.gradient)
                    .frame(width: max(0, geo.size.width * min(value, 1.0)), height: 8)
            }
        }
        .frame(height: 8)
    }
}

