import SwiftUI

struct USBMonitorView: View {
    @ObservedObject var service: USBMonitorService
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text("USB пристрої")
                    .font(.largeTitle.bold())
                Spacer()
                Text("\(service.devices.count) пристроїв")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Button(action: { service.scan() }) {
                    Label("Оновити", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.bordered)
            }
            
            if service.devices.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "cable.connector")
                        .font(.system(size: 48))
                        .foregroundStyle(.secondary)
                    Text("USB пристрої не знайдено")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, minHeight: 200)
            } else {
                List(service.devices) { device in
                    HStack(spacing: 12) {
                        Image(systemName: "cable.connector")
                            .font(.title2)
                            .foregroundStyle(.blue)
                            .frame(width: 32)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(device.name)
                                .font(.body.bold())
                            HStack(spacing: 16) {
                                if device.manufacturer != "—" {
                                    Text(device.manufacturer)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Text("VID: \(device.vendorID)")
                                    .font(.system(.caption2, design: .monospaced))
                                Text("PID: \(device.productID)")
                                    .font(.system(.caption2, design: .monospaced))
                            }
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(device.speed)
                                .font(.caption.bold())
                            if device.serialNumber != "—" {
                                Text(device.serialNumber)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .padding(24)
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear { service.startMonitoring() }
        .onDisappear { service.stopMonitoring() }
    }
}
