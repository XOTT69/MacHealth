import SwiftUI

struct DashboardView: View {
    @ObservedObject var mac: MacDiagService
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                dashboardHeader
                healthHero

                LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                    MetricTile(title: "Процесор", value: mac.cpu.usage.formattedPercent, detail: mac.cpu.name, icon: "cpu", level: mac.cpu.level)
                    MetricTile(title: "Пам'ять", value: mac.ram.usagePercent.formattedPercent, detail: "\(mac.ram.freeGB.formattedGB) доступно", icon: "memorychip", level: mac.ram.level)
                    MetricTile(title: "Сховище", value: mac.storage.usagePercent.formattedPercent, detail: "\(mac.storage.freeGB.formattedGB) вільно", icon: "internaldrive", level: mac.storage.level)
                    MetricTile(title: "Батарея", value: mac.battery.healthDisplay, detail: mac.battery.isPresent ? "\(mac.battery.cycleCount) циклів • \(mac.battery.chargeDisplay) заряд" : mac.battery.condition, icon: "battery.75percent", level: mac.battery.level)
                }

                HStack(alignment: .top, spacing: 16) {
                    DashboardDetailCard(title: "З'єднання", icon: "wifi") {
                        InfoRow(label: "Wi‑Fi", value: mac.network.wifiSSID)
                        InfoRow(label: "Сигнал", value: mac.network.signalDisplay)
                        InfoRow(label: "Швидкість", value: mac.network.wifiSpeed)
                        InfoRow(label: "IP", value: mac.network.localIP)
                    }

                    DashboardDetailCard(title: "Система", icon: "desktopcomputer") {
                        InfoRow(label: "Чіп", value: mac.systemInfo.chip)
                        InfoRow(label: "Дисплей", value: mac.display.resolution)
                        InfoRow(label: "GPU", value: mac.gpu.name)
                        InfoRow(label: "Час роботи", value: mac.systemInfo.uptime)
                    }
                }

                DashboardDetailCard(title: "Стан батареї", icon: "battery.100percent") {
                    if mac.battery.isPresent {
                        ProgressBarSimple(value: mac.battery.healthPercent / 100, level: mac.battery.level)
                            .padding(.bottom, 6)
                        InfoRow(label: "Здоров'я", value: mac.battery.healthDisplay)
                        InfoRow(label: "Ємність", value: "\(mac.battery.maxCapacity) / \(mac.battery.designCapacity) mAh")
                        InfoRow(label: "Статус", value: mac.battery.condition)
                        InfoRow(label: "Час", value: mac.battery.timeRemaining)
                    } else {
                        Text("Вбудовану батарею не виявлено.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(28)
            .frame(maxWidth: 1120)
            .frame(maxWidth: .infinity)
        }
        .background(Color(nsColor: .windowBackgroundColor).ignoresSafeArea())
    }

    private var dashboardHeader: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text("MacHealth")
                    .font(.title.bold())
                Text(mac.systemInfo.modelName == "—" ? "Збір даних про систему" : mac.systemInfo.modelName)
                    .font(.title3)
                    .foregroundStyle(.secondary)
                if let lastUpdated = mac.lastUpdated {
                    Label("Оновлено \(lastUpdated, style: .relative) тому", systemImage: "clock")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
            Spacer()
            Button(action: { mac.fetchAll() }) {
                Label(mac.isLoading ? "Оновлення…" : "Оновити", systemImage: "arrow.clockwise")
            }
            .buttonStyle(.borderedProminent)
            .disabled(mac.isLoading)
        }
    }

    private var healthHero: some View {
        HStack(spacing: 18) {
            Image(systemName: mac.overallHealth.icon)
                .font(.system(size: 42, weight: .semibold))
                .foregroundStyle(Color.statusColor(mac.overallHealth))
                .frame(width: 72, height: 72)
                .background(Circle().fill(Color.statusColor(mac.overallHealth).opacity(0.12)))
            VStack(alignment: .leading, spacing: 4) {
                Text("Загальний стан")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(mac.overallHealth.rawValue)
                    .font(.title2.bold())
                    .foregroundStyle(Color.statusColor(mac.overallHealth))
                Text("Оцінка сформована з доступних показників CPU, пам’яті, сховища та батареї.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(20)
        .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(.background))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Color.statusColor(mac.overallHealth).opacity(0.22), lineWidth: 1))
        .shadow(color: .black.opacity(0.04), radius: 14, y: 5)
    }
}

// MARK: - Components

struct MetricTile: View {
    let title: String
    let value: String
    let detail: String
    let icon: String
    let level: HealthLevel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(Color.statusColor(level))
                    .frame(width: 30, height: 30)
                    .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Color.statusColor(level).opacity(0.12)))
                Spacer()
                Image(systemName: level.icon)
                    .font(.caption)
                    .foregroundStyle(Color.statusColor(level))
            }
            Text(value)
                .font(.title2.bold())
            Text(title)
                .font(.subheadline.weight(.medium))
            Text(detail)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(.background))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color.gray.opacity(0.12), lineWidth: 1))
    }
}

struct DashboardDetailCard<Content: View>: View {
    let title: String
    let icon: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 11) {
            Label(title, systemImage: icon)
                .font(.headline)
            Divider()
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(.background))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color.gray.opacity(0.12), lineWidth: 1))
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
