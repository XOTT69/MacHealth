import SwiftUI

struct NetworkToolsView: View {
    @ObservedObject var mac: MacDiagService
    @ObservedObject var network: NetworkService
    @State private var externalIP: String = "—"
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Text("Мережа")
                    .font(.largeTitle.bold())
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                // Wi-Fi Info
                VStack(alignment: .leading, spacing: 8) {
                    Label("Wi-Fi з'єднання", systemImage: "wifi")
                        .font(.headline)
                    Divider()
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                        InfoRow(label: "Мережа (SSID)", value: mac.network.wifiSSID)
                        InfoRow(label: "Сигнал", value: "\(mac.network.wifiSignal) dBm")
                        InfoRow(label: "Канал", value: "\(mac.network.wifiChannel)")
                        InfoRow(label: "Швидкість", value: mac.network.wifiSpeed)
                        InfoRow(label: "Локальна IP", value: mac.network.localIP)
                        InfoRow(label: "Зовнішня IP", value: externalIP)
                        InfoRow(label: "MAC-адреса", value: mac.network.macAddress)
                        InfoRow(label: "Bluetooth", value: mac.network.bluetoothVersion)
                    }
                }
                .sectionCard()
                
                // Signal Quality
                VStack(alignment: .leading, spacing: 8) {
                    Label("Якість сигналу", systemImage: "antenna.radiowaves.left.and.right")
                        .font(.headline)
                    Divider()
                    HStack(spacing: 20) {
                        signalMeter
                        VStack(alignment: .leading, spacing: 4) {
                            Text(signalQuality)
                                .font(.title3.bold())
                                .foregroundStyle(signalColor)
                            Text("RSSI: \(mac.network.wifiSignal) dBm")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .sectionCard()
            }
            .padding(24)
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear {
            network.fetchExternalIP { ip in
                externalIP = ip
            }
        }
    }
    
    private var signalQuality: String {
        let signal = mac.network.wifiSignal
        if signal == 0 { return "Немає сигналу" }
        if signal > -50 { return "Відмінний" }
        if signal > -60 { return "Дуже добрий" }
        if signal > -70 { return "Добрий" }
        if signal > -80 { return "Слабкий" }
        return "Дуже слабкий"
    }
    
    private var signalColor: Color {
        let signal = mac.network.wifiSignal
        if signal == 0 { return .gray }
        if signal > -50 { return .green }
        if signal > -60 { return .blue }
        if signal > -70 { return .orange }
        return .red
    }
    
    private var signalMeter: some View {
        HStack(spacing: 3) {
            ForEach(0..<5) { i in
                RoundedRectangle(cornerRadius: 2)
                    .fill(barFilled(i) ? signalColor : Color.gray.opacity(0.2))
                    .frame(width: 8, height: CGFloat(10 + i * 8))
            }
        }
        .frame(height: 50)
    }
    
    private func barFilled(_ index: Int) -> Bool {
        let signal = mac.network.wifiSignal
        if signal == 0 { return false }
        let thresholds = [-80, -70, -60, -50, -30]
        return signal > thresholds[index]
    }
}

struct SpeedTestView: View {
    @ObservedObject var network: NetworkService
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Text("Speed Test")
                    .font(.largeTitle.bold())
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                Button(action: { network.runSpeedTest() }) {
                    Label(network.speedTest.isRunning ? "Тестування..." : "Запустити тест", systemImage: "speedometer")
                        .font(.headline)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(network.speedTest.isRunning)
                
                if network.speedTest.isRunning {
                    VStack(spacing: 8) {
                        ProgressView(value: network.speedTest.progress)
                        Text(network.speedTest.status)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .sectionCard()
                }
                
                if network.speedTest.progress >= 1.0 {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                        VStack {
                            Text("⬇️")
                                .font(.title)
                            Text(String(format: "%.1f", network.speedTest.downloadMbps))
                                .font(.title.bold())
                            Text("Мбіт/с")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text("Завантаження")
                                .font(.caption2)
                        }
                        .cardStyle()
                        
                        VStack {
                            Text("⬆️")
                                .font(.title)
                            Text(String(format: "%.1f", network.speedTest.uploadMbps))
                                .font(.title.bold())
                            Text("Мбіт/с")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text("Вивантаження")
                                .font(.caption2)
                        }
                        .cardStyle()
                        
                        VStack {
                            Text("🏓")
                                .font(.title)
                            Text(String(format: "%.0f", network.speedTest.ping))
                                .font(.title.bold())
                            Text("мс")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text("Ping")
                                .font(.caption2)
                        }
                        .cardStyle()
                    }
                }
            }
            .padding(24)
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

struct PingView: View {
    @ObservedObject var network: NetworkService
    @State private var host: String = "google.com"
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Ping")
                    .font(.largeTitle.bold())
                Spacer()
            }
            
            HStack {
                TextField("Хост (google.com)", text: $host)
                    .textFieldStyle(.roundedBorder)
                Button(action: { network.ping(host: host) }) {
                    Label(network.isPinging ? "..." : "Ping", systemImage: "network")
                }
                .buttonStyle(.borderedProminent)
                .disabled(network.isPinging || host.isEmpty)
            }
            
            List(network.pingResults) { result in
                HStack {
                    Image(systemName: result.isSuccess ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundStyle(result.isSuccess ? .green : .red)
                    Text(result.host)
                    Spacer()
                    if result.isSuccess {
                        Text(String(format: "%.1f мс", result.time))
                            .font(.system(.body, design: .monospaced))
                        Text("TTL: \(result.ttl)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("Timeout")
                            .foregroundStyle(.red)
                    }
                }
            }
        }
        .padding(24)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

struct LocalScanView: View {
    @ObservedObject var network: NetworkService
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Сканер мережі")
                    .font(.largeTitle.bold())
                Spacer()
                Button(action: { network.scanLocalNetwork() }) {
                    Label(network.isScanning ? "Сканування..." : "Сканувати", systemImage: "antenna.radiowaves.left.and.right")
                }
                .buttonStyle(.borderedProminent)
                .disabled(network.isScanning)
            }
            
            if network.isScanning {
                ProgressView("Сканування локальної мережі...")
            }
            
            List(network.localDevices) { device in
                HStack {
                    Image(systemName: "desktopcomputer")
                        .foregroundStyle(.blue)
                    VStack(alignment: .leading) {
                        Text(device.hostname.isEmpty ? device.ip : device.hostname)
                            .font(.body.bold())
                        Text(device.ip)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text(device.mac)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
            }
            
            if !network.localDevices.isEmpty {
                Text("Знайдено пристроїв: \(network.localDevices.count)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(24)
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear { network.scanLocalNetwork() }
    }
}
