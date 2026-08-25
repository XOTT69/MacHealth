import SwiftUI

struct DashboardView: View {
    @ObservedObject var mac: MacDiagService
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header
                HStack {
                    VStack(alignment: .leading) {
                        Text("Панель керування")
                            .font(.largeTitle.bold())
                        Text(mac.systemInfo.modelName + " • " + mac.systemInfo.osVersion)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button(action: { mac.fetchAll() }) {
                        Label("Оновити", systemImage: "arrow.clockwise")
                    }
                    .buttonStyle(.borderedProminent)
                }
                
                // Overall Health
                HStack(spacing: 16) {
                    Image(systemName: mac.overallHealth.icon)
                        .font(.system(size: 44))
                        .foregroundStyle(Color.statusColor(mac.overallHealth))
                    VStack(alignment: .leading) {
                        Text("Загальний стан")
                            .font(.headline)
                        Text(mac.overallHealth.rawValue)
                            .font(.title2.bold())
                            .foregroundStyle(Color.statusColor(mac.overallHealth))
                    }
                    Spacer()
                    VStack(alignment: .trailing) {
                        Text(mac.systemInfo.chip)
                            .font(.caption)
                        Text(mac.systemInfo.memory)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .sectionCard()
                
                // Quick Stats Grid
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    QuickStatCard(title: "CPU", value: mac.cpu.usage.formattedPercent, icon: "cpu", level: mac.cpu.level)
                    QuickStatCard(title: "RAM", value: mac.ram.usagePercent.formattedPercent, icon: "memorychip", level: mac.ram.level)
                    QuickStatCard(title: "Диск", value: mac.storage.usagePercent.formattedPercent, icon: "internaldrive", level: mac.storage.level)
                    QuickStatCard(title: "Батарея", value: mac.battery.healthDisplay, icon: "battery.75percent", level: mac.battery.level)
                }
                
                // Details Row
                HStack(spacing: 16) {
                    // Network Card
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Мережа", systemImage: "wifi")
                            .font(.headline)
                        Divider()
                        InfoRow(label: "Wi-Fi", value: mac.network.wifiSSID)
                        InfoRow(label: "IP", value: mac.network.localIP)
                        InfoRow(label: "Сигнал", value: "\(mac.network.wifiSignal) dBm")
                        InfoRow(label: "Швидкість", value: mac.network.wifiSpeed)
                    }
                    .cardStyle()
                    
                    // System Card
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Система", systemImage: "desktopcomputer")
                            .font(.headline)
                        Divider()
                        InfoRow(label: "Серійний №", value: mac.systemInfo.serialNumber)
                        InfoRow(label: "Uptime", value: mac.systemInfo.uptime)
                        InfoRow(label: "Дисплей", value: mac.display.resolution)
                        InfoRow(label: "GPU", value: mac.gpu.name)
                    }
                    .cardStyle()
                }
                
                // Battery + Storage Row
                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Батарея", systemImage: "battery.75percent")
                            .font(.headline)
                        Divider()
                        ProgressBarSimple(value: mac.battery.healthPercent / 100, level: mac.battery.level)
                        InfoRow(label: "Здоров'я", value: mac.battery.healthDisplay)
                        InfoRow(label: "Цикли", value: "\(mac.battery.cycleCount)")
                        InfoRow(label: "Стан", value: mac.battery.condition)
                        InfoRow(label: "Температура", value: mac.battery.temperature.formattedTemp)
                    }
                    .cardStyle()
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Сховище", systemImage: "internaldrive")
                            .font(.headline)
                        Divider()
                        ProgressBarSimple(value: mac.storage.usagePercent / 100, level: mac.storage.level)
                        InfoRow(label: "Використано", value: "\(mac.storage.usedGB.formattedGB) / \(mac.storage.totalGB.formattedGB)")
                        InfoRow(label: "Вільно", value: mac.storage.freeGB.formattedGB)
                        InfoRow(label: "SMART", value: mac.storage.smartStatus)
                        InfoRow(label: "Тип", value: mac.storage.type)
                    }
                    .cardStyle()
                }
            }
            .padding(24)
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

// MARK: - Components

struct QuickStatCard: View {
    let title: String
    let value: String
    let icon: String
    let level: HealthLevel
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(Color.statusColor(level))
            Text(value)
                .font(.title3.bold())
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.statusColor(level).opacity(0.05)))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.statusColor(level).opacity(0.2), lineWidth: 1))
    }
}

struct InfoRow: View {
    let label: String
    let value: String
    
    var body: some View {
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
}

struct ProgressBarSimple: View {
    let value: Double
    let level: HealthLevel
    
    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.gray.opacity(0.15))
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.statusColor(level).gradient)
                    .frame(width: max(0, geo.size.width * min(value, 1.0)))
            }
        }
        .frame(height: 8)
    }
}
