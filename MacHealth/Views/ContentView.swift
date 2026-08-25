import SwiftUI

struct ContentView: View {
    @State private var selectedTab: DiagnosticTab = .mac
    
    var body: some View {
        NavigationSplitView {
            SidebarView(selectedTab: $selectedTab)
                .navigationSplitViewColumnWidth(min: 220, ideal: 250)
        } detail: {
            switch selectedTab {
            case .mac:
                MacDiagnosticsView()
            case .iphone:
                iPhoneDiagnosticsView()
            case .report:
                ReportView()
            }
        }
        .navigationTitle("MacHealth")
    }
}

enum DiagnosticTab: String, CaseIterable {
    case mac = "MacBook"
    case iphone = "iPhone"
    case report = "Звіт"
    
    var icon: String {
        switch self {
        case .mac: return "laptopcomputer"
        case .iphone: return "iphone"
        case .report: return "doc.text.magnifyingglass"
        }
    }
    
    var title: String {
        switch self {
        case .mac: return "Діагностика Mac"
        case .iphone: return "Діагностика iPhone"
        case .report: return "Звіт та рекомендації"
        }
    }
}

struct SidebarView: View {
    @Binding var selectedTab: DiagnosticTab
    
    var body: some View {
        List(DiagnosticTab.allCases, id: \.self, selection: $selectedTab) { tab in
            Label(tab.title, systemImage: tab.icon)
                .font(.system(size: 14, weight: .medium))
                .padding(.vertical, 4)
        }
        .listStyle(.sidebar)
        .safeAreaInset(edge: .top) {
            VStack(spacing: 8) {
                Image(systemName: "stethoscope")
                    .font(.system(size: 36))
                    .foregroundStyle(.blue.gradient)
                Text("MacHealth")
                    .font(.title2.bold())
                Text("Діагностика пристроїв")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity)
        }
    }
}

