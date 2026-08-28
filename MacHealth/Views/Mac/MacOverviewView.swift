import SwiftUI

struct MacOverviewView: View {
    @ObservedObject var mac: MacDiagService
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                HStack {
                    Text("Огляд Mac")
                        .font(.largeTitle.bold())
                    Spacer()
                    Button(action: { mac.fetchAll() }) {
                        Label("Оновити", systemImage: "arrow.clockwise")
                    }
                    .buttonStyle(.borderedProminent)
                }
                
                // System Info
                VStack(alignment: .leading, spacing: 12) {
                    Label("Інформація про систему", systemImage: "desktopcomputer")
                        .font(.headline)
                    Divider()
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                        InfoRow(label: "Модель", value: mac.systemInfo.modelName)
                        InfoRow(label: "Ідентифікатор", value: mac.systemInfo.modelIdentifier)
                        InfoRow(label: "Серійний номер", value: mac.systemInfo.serialNumber)
                        InfoRow(label: "macOS", value: mac.systemInfo.osVersion)
                        InfoRow(label: "Чіп", value: mac.systemInfo.chip)
                        InfoRow(label: "Пам'ять", value: mac.systemInfo.memory)
                        InfoRow(label: "Час роботи", value: mac.systemInfo.uptime)
                        InfoRow(label: "Дисплей", value: mac.display.resolution)
                    }
                }
                .sectionCard()
                
                // CPU + GPU
                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Процесор", systemImage: "cpu")
                            .font(.headline)
                        Divider()
                        ProgressBarSimple(value: mac.cpu.usage / 100, level: mac.cpu.level)
                        InfoRow(label: "Модель", value: mac.cpu.name)
                        InfoRow(label: "Ядра", value: "\(mac.cpu.cores) (P:\(mac.cpu.perfCores) E:\(mac.cpu.effCores))")
                        InfoRow(label: "Навантаження", value: mac.cpu.usageDisplay)
                    }
                    .cardStyle()
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Графіка", systemImage: "gpu")
                            .font(.headline)
                        Divider()
                        InfoRow(label: "GPU", value: mac.gpu.name)
                        InfoRow(label: "Ядра", value: mac.gpu.cores > 0 ? "\(mac.gpu.cores)" : "—")
                        InfoRow(label: "Metal", value: mac.gpu.metal)
                    }
                    .cardStyle()
                }
                
                // RAM
                VStack(alignment: .leading, spacing: 8) {
                    Label("Оперативна пам'ять", systemImage: "memorychip")
                        .font(.headline)
                    Divider()
                    ProgressBarSimple(value: mac.ram.usagePercent / 100, level: mac.ram.level)
                    HStack(spacing: 16) {
                        InfoRow(label: "Всього", value: mac.ram.isAvailable ? mac.ram.totalGB.formattedGB : "—")
                        InfoRow(label: "Використано", value: mac.ram.isAvailable ? mac.ram.usedGB.formattedGB : "—")
                        InfoRow(label: "Доступно", value: mac.ram.freeDisplay)
                        InfoRow(label: "Тип", value: mac.ram.type)
                    }
                }
                .sectionCard()
                
                // Network
                VStack(alignment: .leading, spacing: 8) {
                    Label("Мережа", systemImage: "wifi")
                        .font(.headline)
                    Divider()
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                        InfoRow(label: "Wi-Fi", value: mac.network.wifiSSID)
                        InfoRow(label: "Сигнал", value: mac.network.signalDisplay)
                        InfoRow(label: "Канал", value: mac.network.channelDisplay)
                        InfoRow(label: "Швидкість", value: mac.network.wifiSpeed)
                        InfoRow(label: "IP", value: mac.network.localIP)
                        InfoRow(label: "MAC", value: mac.network.macAddress)
                        InfoRow(label: "Bluetooth", value: mac.network.bluetoothVersion)
                        InfoRow(label: "Wi-Fi", value: mac.network.isWifiOn ? "Увімкнено" : "Вимкнено")
                    }
                }
                .sectionCard()
            }
            .padding(24)
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

struct BatteryDetailView: View {
    @ObservedObject var mac: MacDiagService
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Text("Батарея")
                    .font(.largeTitle.bold())
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                // Health Circle
                HStack(spacing: 24) {
                    ZStack {
                        Circle()
                            .stroke(Color.gray.opacity(0.2), lineWidth: 12)
                        Circle()
                            .trim(from: 0, to: mac.battery.healthPercent / 100)
                            .stroke(Color.statusColor(mac.battery.level), style: StrokeStyle(lineWidth: 12, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                        VStack {
                            Text(mac.battery.healthDisplay)
                                .font(.title.bold())
                            Text("Здоров'я")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .frame(width: 120, height: 120)
                    
                    VStack(alignment: .leading, spacing: 12) {
                        Label(mac.battery.condition, systemImage: mac.battery.level.icon)
                            .font(.title3.bold())
                            .foregroundStyle(Color.statusColor(mac.battery.level))
                        
                        InfoRow(label: "Цикли заряду", value: "\(mac.battery.cycleCount)")
                        InfoRow(label: "Температура", value: mac.battery.temperatureDisplay)
                        InfoRow(label: "Напруга", value: String(format: "%.2f В", mac.battery.voltage))
                        InfoRow(label: "Зарядка", value: mac.battery.isCharging ? "⚡ Так" : "Ні")
                        InfoRow(label: "Час", value: mac.battery.timeRemaining)
                    }
                    Spacer()
                }
                .sectionCard()
                
                // Capacity Details
                VStack(alignment: .leading, spacing: 8) {
                    Label("Ємність", systemImage: "battery.100percent")
                        .font(.headline)
                    Divider()
                    InfoRow(label: "Поточна максимальна", value: mac.battery.healthAvailable ? "\(mac.battery.maxCapacity) mAh" : "Недоступно")
                    InfoRow(label: "Заводська", value: mac.battery.healthAvailable ? "\(mac.battery.designCapacity) mAh" : "Недоступно")
                    InfoRow(label: "Поточний заряд", value: mac.battery.chargeAvailable ? "\(mac.battery.currentCharge) mAh (\(mac.battery.chargeDisplay))" : "Недоступно")
                    InfoRow(label: "Втрачено", value: mac.battery.healthAvailable ? "\(max(0, mac.battery.designCapacity - mac.battery.maxCapacity)) mAh" : "Недоступно")
                }
                .sectionCard()
                
                // Recommendations
                VStack(alignment: .leading, spacing: 8) {
                    Label("Рекомендації", systemImage: "wrench.and.screwdriver")
                        .font(.headline)
                    Divider()
                    if !mac.battery.isPresent {
                        Text("На цьому Mac вбудовану батарею не виявлено.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    } else if !mac.battery.healthAvailable {
                        Text("macOS не надала дані про заводську та поточну ємність батареї.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    } else if mac.battery.healthPercent < 80 {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.orange)
                            Text("Рекомендуємо замінити батарею. Орієнтовна вартість: ₴2000–4000")
                                .font(.subheadline)
                        }
                    } else if mac.battery.cycleCount > 800 {
                        HStack {
                            Image(systemName: "info.circle.fill")
                                .foregroundStyle(.blue)
                            Text("Кількість циклів наближається до максимуму (1000). Плануйте заміну.")
                                .font(.subheadline)
                        }
                    } else {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                            Text("Батарея в хорошому стані. Заміна не потрібна.")
                                .font(.subheadline)
                        }
                    }
                }
                .sectionCard()
            }
            .padding(24)
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

struct StorageDetailView: View {
    @ObservedObject var mac: MacDiagService
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Text("Сховище")
                    .font(.largeTitle.bold())
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                VStack(alignment: .leading, spacing: 12) {
                    ProgressBarSimple(value: mac.storage.usagePercent / 100, level: mac.storage.level)
                        .frame(height: 16)
                    
                    HStack {
                        Text("Використано: \(mac.storage.isAvailable ? mac.storage.usedGB.formattedGB : "—")")
                        Spacer()
                        Text("Вільно: \(mac.storage.freeDisplay)")
                        Spacer()
                        Text("Всього: \(mac.storage.isAvailable ? mac.storage.totalGB.formattedGB : "—")")
                    }
                    .font(.subheadline)
                }
                .sectionCard()
                
                VStack(alignment: .leading, spacing: 8) {
                    Label("Деталі", systemImage: "internaldrive")
                        .font(.headline)
                    Divider()
                    InfoRow(label: "Тип носія", value: mac.storage.type)
                    InfoRow(label: "Файлова система", value: mac.storage.fileSystem)
                    InfoRow(label: "SMART статус", value: mac.storage.smartStatus)
                    InfoRow(label: "Використання", value: mac.storage.usageDisplay)
                }
                .sectionCard()
            }
            .padding(24)
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

struct ProcessesView: View {
    @State private var processes: [MacHealth.ProcessInfo] = []
    @State private var sortBy: String = "cpu"
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Процеси")
                    .font(.largeTitle.bold())
                Spacer()
                Picker("Сортувати", selection: $sortBy) {
                    Text("CPU").tag("cpu")
                    Text("RAM").tag("ram")
                }
                .pickerStyle(.segmented)
                .frame(width: 150)
                Button(action: fetchProcesses) {
                    Label("Оновити", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.bordered)
            }
            .padding(.horizontal, 24)
            .padding(.top, 24)
            
            List(processes) { proc in
                HStack {
                    Text(proc.name)
                        .font(.system(.body, design: .monospaced))
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text(String(format: "%.1f%%", proc.cpuPercent))
                        .font(.caption.bold())
                        .foregroundStyle(proc.cpuPercent > 50 ? .red : .primary)
                        .frame(width: 60)
                    Text(String(format: "%.0f MB", proc.memMB))
                        .font(.caption)
                        .frame(width: 70)
                    Text("PID: \(proc.pid)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .frame(width: 70)
                }
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear { fetchProcesses() }
    }
    
    private func fetchProcesses() {
        let order = sortBy
        DispatchQueue.global(qos: .userInitiated).async {
            let output = Shell.run("/bin/ps", arguments: ["-A", "-o", "user=,pid=,%cpu=,rss=,comm="]).output
            var procs: [MacHealth.ProcessInfo] = []
            
            for line in output.components(separatedBy: "\n") {
                let parts = line.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
                guard parts.count >= 5 else { continue }
                
                var proc = MacHealth.ProcessInfo()
                proc.user = parts[0]
                proc.pid = Int(parts[1]) ?? 0
                proc.cpuPercent = Double(parts[2]) ?? 0
                proc.memMB = (Double(parts[3]) ?? 0) / 1024
                proc.name = parts[4...].joined(separator: " ")
                procs.append(proc)
            }
            procs.sort { order == "cpu" ? $0.cpuPercent > $1.cpuPercent : $0.memMB > $1.memMB }
            procs = Array(procs.prefix(30))
            
            DispatchQueue.main.async {
                processes = procs
            }
        }
    }
}
