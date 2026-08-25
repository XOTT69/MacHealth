import SwiftUI

struct iPhoneDiagnosticsView: View {
    @StateObject private var service = iPhoneDiagnosticService()
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Заголовок
                headerSection
                
                if service.isLoading {
                    loadingView
                } else if !service.phoneInfo.isConnected {
                    notConnectedView
                } else {
                    // iPhone підключено
                    connectedView
                }
            }
            .padding(24)
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear {
            service.checkConnection()
        }
    }
    
    // MARK: - Header
    
    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Діагностика iPhone")
                    .font(.largeTitle.bold())
                Text("Аналіз стану підключеного iPhone")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            Button(action: { service.checkConnection() }) {
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
            Text("Пошук підключеного iPhone...")
                .font(.headline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 300)
    }
    
    // MARK: - Not Connected
    
    private var notConnectedView: some View {
        VStack(spacing: 24) {
            Image(systemName: "iphone.slash")
                .font(.system(size: 64))
                .foregroundStyle(.secondary)
            
            Text("iPhone не підключено")
                .font(.title2.bold())
            
            if let error = service.errorMessage {
                Text(error)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            
            VStack(alignment: .leading, spacing: 12) {
                instructionRow(number: "1", text: "Підключіть iPhone до Mac через USB-кабель")
                instructionRow(number: "2", text: "Розблокуйте iPhone та натисніть «Довіряти»")
                instructionRow(number: "3", text: "Натисніть кнопку «Оновити» вище")
            }
            .padding(24)
            .background(RoundedRectangle(cornerRadius: 12).fill(Color.blue.opacity(0.05)))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.blue.opacity(0.2), lineWidth: 1))
            
            VStack(alignment: .leading, spacing: 8) {
                Text("💡 Для повної діагностики:")
                    .font(.headline)
                Text("Встановіть libimobiledevice через Homebrew:")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                
                HStack {
                    Text("brew install libimobiledevice")
                        .font(.system(.body, design: .monospaced))
                        .padding(8)
                        .background(RoundedRectangle(cornerRadius: 6).fill(Color.gray.opacity(0.1)))
                    
                    Button(action: {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString("brew install libimobiledevice", forType: .string)
                    }) {
                        Image(systemName: "doc.on.doc")
                    }
                    .buttonStyle(.bordered)
                    .help("Копіювати команду")
                }
            }
            .padding(20)
            .background(RoundedRectangle(cornerRadius: 12).fill(.background))
            .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
        }
        .frame(maxWidth: .infinity, minHeight: 400)
    }
    
    // MARK: - Connected View
    
    private var connectedView: some View {
        VStack(spacing: 16) {
            // Статус підключення
            HStack(spacing: 12) {
                Image(systemName: "iphone")
                    .font(.system(size: 36))
                    .foregroundStyle(.green)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(service.phoneInfo.deviceName)
                        .font(.title2.bold())
                    Text(service.phoneInfo.modelName)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                Label("Підключено", systemImage: "checkmark.circle.fill")
                    .font(.subheadline.bold())
                    .foregroundStyle(.green)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(.green.opacity(0.1)))
            }
            .padding(20)
            .background(RoundedRectangle(cornerRadius: 16).fill(.background))
            .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
            
            // Попередження (якщо є)
            if let error = service.errorMessage {
                HStack {
                    Image(systemName: "info.circle.fill")
                        .foregroundStyle(.orange)
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 8).fill(.orange.opacity(0.05)))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(.orange.opacity(0.2), lineWidth: 1))
            }
            
            // Інформація
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                // Загальна інформація
                iPhoneInfoCard
                
                // Батарея
                iPhoneBatteryCard
            }
            
            // Рекомендації
            if !service.recommendations.isEmpty {
                recommendationsSection
            }
        }
    }
    
    // MARK: - iPhone Info Card
    
    private var iPhoneInfoCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "info.circle")
                    .font(.title3)
                    .foregroundStyle(.blue)
                Text("Інформація")
                    .font(.headline)
            }
            
            Divider()
            
            VStack(alignment: .leading, spacing: 6) {
                detailRow(label: "Серійний №", value: service.phoneInfo.serialNumber)
                detailRow(label: "IMEI", value: service.phoneInfo.imei)
                detailRow(label: "iOS", value: service.phoneInfo.iosVersion)
                detailRow(label: "Збірка", value: service.phoneInfo.buildVersion)
                detailRow(label: "Wi-Fi MAC", value: service.phoneInfo.wifiMAC)
                detailRow(label: "Bluetooth", value: service.phoneInfo.bluetoothMAC)
                detailRow(label: "Активація", value: service.phoneInfo.activationStatus)
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 12).fill(.background))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.gray.opacity(0.1), lineWidth: 1))
        .shadow(color: .black.opacity(0.03), radius: 4, y: 2)
    }
    
    // MARK: - iPhone Battery Card
    
    private var iPhoneBatteryCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "battery.75percent")
                    .font(.title3)
                    .foregroundStyle(.green)
                Text("Батарея та пам'ять")
                    .font(.headline)
            }
            
            Divider()
            
            VStack(alignment: .leading, spacing: 6) {
                if service.phoneInfo.batteryLevel > 0 {
                    detailRow(label: "Рівень заряду", value: "\(service.phoneInfo.batteryLevel)%")
                }
                if service.phoneInfo.batteryHealth > 0 && service.phoneInfo.batteryHealth <= 100 {
                    detailRow(label: "Здоров'я батареї", value: "\(service.phoneInfo.batteryHealth)%")
                }
                detailRow(label: "Загальна пам'ять", value: service.phoneInfo.totalStorage)
                detailRow(label: "Вільна пам'ять", value: service.phoneInfo.freeStorage)
            }
            
            if service.phoneInfo.batteryHealth > 0 {
                Divider()
                let healthStatus: HealthStatus = service.phoneInfo.batteryHealth >= 80 ? .good :
                    service.phoneInfo.batteryHealth >= 60 ? .warning : .critical
                HStack {
                    Image(systemName: healthStatus.icon)
                        .foregroundStyle(healthStatusColor(healthStatus))
                    Text(healthStatus.label)
                        .font(.caption.bold())
                        .foregroundStyle(healthStatusColor(healthStatus))
                }
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 12).fill(.background))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.gray.opacity(0.1), lineWidth: 1))
        .shadow(color: .black.opacity(0.03), radius: 4, y: 2)
    }
    
    // MARK: - Recommendations
    
    private var recommendationsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Рекомендації", systemImage: "wrench.and.screwdriver")
                .font(.headline)
            
            ForEach(service.recommendations) { rec in
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: rec.status.icon)
                        .foregroundStyle(healthStatusColor(rec.status))
                        .font(.title3)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(rec.title)
                            .font(.subheadline.bold())
                        Text(rec.description)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        if let cost = rec.estimatedCost {
                            Text("💰 \(cost)")
                                .font(.caption.bold())
                                .foregroundStyle(.orange)
                        }
                    }
                }
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 8).fill(healthStatusColor(rec.status).opacity(0.05)))
            }
        }
        .padding(20)
        .background(RoundedRectangle(cornerRadius: 16).fill(.background))
        .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
    }
    
    // MARK: - Helpers
    
    private func instructionRow(number: String, text: String) -> some View {
        HStack(spacing: 12) {
            Text(number)
                .font(.caption.bold())
                .frame(width: 24, height: 24)
                .background(Circle().fill(.blue))
                .foregroundStyle(.white)
            Text(text)
                .font(.subheadline)
        }
    }
    
    private func detailRow(label: String, value: String) -> some View {
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
    
    private func healthStatusColor(_ status: HealthStatus) -> Color {
        switch status {
        case .good: return .green
        case .warning: return .orange
        case .critical: return .red
        }
    }
}

