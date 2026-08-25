import SwiftUI
import AppKit

struct ReportView: View {
    @ObservedObject var mac: MacDiagService
    @ObservedObject var phone: iPhoneService
    @ObservedObject var network: NetworkService
    @State private var reportText: String = ""
    @State private var showCopied = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                HStack {
                    Text("Звіт діагностики")
                        .font(.largeTitle.bold())
                    Spacer()
                }
                
                // Actions
                HStack(spacing: 12) {
                    Button(action: generateReport) {
                        Label("Згенерувати", systemImage: "doc.text")
                            .font(.headline)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    
                    Button(action: {
                        ReportService.saveReport(reportText)
                    }) {
                        Label("Зберегти", systemImage: "square.and.arrow.down")
                    }
                    .buttonStyle(.bordered)
                    .disabled(reportText.isEmpty)
                    
                    Button(action: {
                        ReportService.copyToClipboard(reportText)
                        showCopied = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { showCopied = false }
                    }) {
                        Label("Копіювати", systemImage: "doc.on.doc")
                    }
                    .buttonStyle(.bordered)
                    .disabled(reportText.isEmpty)
                    
                    Spacer()
                    
                    if showCopied {
                        Label("Скопійовано!", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    }
                }
                
                if !reportText.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Label("Попередній перегляд", systemImage: "doc.plaintext")
                                .font(.headline)
                            Spacer()
                            Text("\(reportText.count) символів")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Divider()
                        Text(reportText)
                            .font(.system(.caption, design: .monospaced))
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .sectionCard()
                }
            }
            .padding(24)
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear { generateReport() }
    }
    
    private func generateReport() {
        reportText = ReportService.generateReport(mac: mac, phone: phone, network: network)
    }
}
