import SwiftUI

struct MainView: View {
    @State private var selectedItem: SidebarItem = .dashboard
    @StateObject private var macService = MacDiagService()
    @StateObject private var phoneService = iPhoneService()
    @StateObject private var networkService = NetworkService()
    @StateObject private var usbService = USBMonitorService()
    @StateObject private var testService = HardwareTestService()
    
    var body: some View {
        NavigationSplitView {
            SidebarView(selected: $selectedItem)
                .navigationSplitViewColumnWidth(min: 200, ideal: 230)
        } detail: {
            detailView
        }
        .navigationTitle("")
        .onAppear {
            macService.startMonitoring()
        }
        .onDisappear {
            macService.stopMonitoring()
        }
    }
    
    @ViewBuilder
    private var detailView: some View {
        switch selectedItem {
        case .dashboard:
            DashboardView(mac: macService)
        case .macOverview:
            MacOverviewView(mac: macService)
        case .macBattery:
            BatteryDetailView(mac: macService)
        case .macStorage:
            StorageDetailView(mac: macService)
        case .macProcesses:
            ProcessesView()
        case .iPhone:
            iPhoneMainView(service: phoneService)
        case .network:
            NetworkToolsView(mac: macService, network: networkService)
        case .speedTest:
            SpeedTestView(network: networkService)
        case .ping:
            PingView(network: networkService)
        case .localScan:
            LocalScanView(network: networkService)
        case .usb:
            USBMonitorView(service: usbService)
        case .hardwareTest:
            HardwareTestsView(service: testService)
        case .report:
            ReportView(mac: macService, phone: phoneService, network: networkService)
        }
    }
}

struct SidebarView: View {
    @Binding var selected: SidebarItem
    
    private let sections: [(String, [SidebarItem])] = [
        ("Головна", [.dashboard]),
        ("Mac", [.macOverview, .macBattery, .macStorage, .macProcesses]),
        ("iPhone", [.iPhone]),
        ("Мережа", [.network, .speedTest, .ping, .localScan]),
        ("Пристрої", [.usb]),
        ("Тести", [.hardwareTest]),
        ("Звіти", [.report])
    ]
    
    var body: some View {
        List(selection: $selected) {
            ForEach(sections, id: \.0) { section in
                Section(section.0) {
                    ForEach(section.1) { item in
                        Label(item.rawValue, systemImage: item.icon)
                            .tag(item)
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .safeAreaInset(edge: .top) {
            VStack(spacing: 6) {
                Image(systemName: "stethoscope")
                    .font(.system(size: 28))
                    .foregroundStyle(.blue.gradient)
                Text("MacHealth")
                    .font(.headline)
                Text("v2.0")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
        }
    }
}
