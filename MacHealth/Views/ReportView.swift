import SwiftUI
import AppKit

struct ReportView: View {
    @StateObject private var macService = MacDiagnosticService()
    @StateObject private var iPhoneService = iPhoneDiagnosticService()
    @State private var reportText: String = ""
    @State private var isGenerating = false
    @State private var savedURL: URL?
    @State private var showSaveSuccess = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Заголовок
                headerSection
                
                // Кнопки дій
                actionsSection
                
                // Попередній перегляд звіту
                if !reportText.isEmpty {
                    reportPreview
                }
                
                // Рекомендації
                if !macService.recommendations.isEmpty {
                    recommendationsOverview
                }
            }
            .padding(24)
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear {
            generateReport()
        }
    }
    
    // MARK: - Header
    
    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Звіт та рекомендації")
                    .font(.largeTitle.bold())
                Text("Повний звіт про стан пристроїв з рекомендаціями")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
        }
    }
    
    // MARK: - Actions
    
    private var actionsSection: some View {
        HStack(spacing: 12) {
            Button(action: generateReport) {
                Label("Згенерувати звіт", systemImage: "doc.text")
                    .font(.headline)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(isGenerating)
            
            Button(action: saveToFile) {
                Label("Зберегти у файл", systemImage: "square.and.arrow.down")
                    .font(.headline)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .disabled(reportText.isEmpty)
            
            Button(action: copyToClipboard) {
                Label("Копіювати", systemImage: "doc.on.doc")
                    .font(.headline)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .disabled(reportText.isEmpty)
            
            Spacer()
            
            if showSaveSuccess {
                Label("Збережено!", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .font(.subheadline.bold())
                    .transition(.opacity)
            }
        }
    }
    
    // MARK: - Report Preview
    
    private var reportPreview: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Попередній перегляд звіту", systemImage: "doc.plaintext")
                    .font(.headline)
                Spacer()
                Text("\(reportText.count) символів")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Divider()
            
            ScrollView {
                Text(reportText)
                    .font(.system(.body, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxHeight: 500)
        }
        .padding(20)
        .background(RoundedRectangle(cornerRadius: 16).fill(.background))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.gray.opacity(0.1), lineWidth: 1))
        .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
    }
    
    // MARK: - Recommendations Overview
    
    private var recommendationsOverview: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("Рекомендації по ремонту та обслуговуванню", systemImage: "wrench.and.screwdriver")
                .font(.title3.bold())
            
            // Підсумок
            HStack(spacing: 20) {
                summaryBadge(
                    count: macService.recommendations.filter { $0.status == .good }.count,
                    status: .good,
                    label: "В нормі"
                )
                summaryBadge(
                    count: macService.recommendations.filter { $0.status == .warning }.count,
                    status: .warning,
                    label: "Увага"
                )
                summaryBadge(
                    count: macService.recommendations.filter { $0.status == .critical }.count,
                    status: .critical,
                    label: "Критично"
                )
                Spacer()
            }
            
            Divider()
            
            // Список рекомендацій
            ForEach(macService.recommendations) { rec in
                recommendationCard(rec)
            }
        }
        .padding(20)
        .background(RoundedRectangle(cornerRadius: 16).fill(.background))
        .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
    }
    
    // MARK: - Recommendation Card
    
    private func recommendationCard(_ rec: Recommendation) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: rec.status.icon)
                .font(.title2)
                .foregroundStyle(statusColor(rec.status))
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(rec.category)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(statusColor(rec.status).opacity(0.1)))
                    Spacer()
                    if let cost = rec.estimatedCost {
                        Text("💰 \(cost)")
                            .font(.caption.bold())
                            .foregroundStyle(.orange)
                    }
                }
                
                Text(rec.title)
                    .font(.subheadline.bold())
                
                Text(rec.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 12).fill(statusColor(rec.status).opacity(0.03)))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(statusColor(rec.status).opacity(0.15), lineWidth: 1))
    }
    
    // MARK: - Summary Badge
    
    private func summaryBadge(count: Int, status: HealthStatus, label: String) -> some View {
        VStack(spacing: 4) {
            Text("\(count)")
                .font(.title.bold())
                .foregroundStyle(statusColor(status))
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(width: 80)
        .padding(.vertical, 12)
        .background(RoundedRectangle(cornerRadius: 8).fill(statusColor(status).opacity(0.05)))
    }
    
    // MARK: - Actions
    
    private func generateReport() {
        isGenerating = true
        macService.runFullDiagnostics()
        iPhoneService.checkConnection()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            reportText = ReportGenerator.generateTextReport(
                macService: macService,
                iPhoneService: iPhoneService
            )
            isGenerating = false
        }
    }
    
    private func saveToFile() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.plainText]
        panel.nameFieldStringValue = "MacHealth_Report.txt"
        panel.title = "Зберегти звіт"
        panel.message = "Виберіть місце для збереження звіту діагностики"
        
        panel.begin { response in
            if response == .OK, let url = panel.url {
                do {
                    try reportText.write(to: url, atomically: true, encoding: .utf8)
                    savedURL = url
                    withAnimation {
                        showSaveSuccess = true
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                        withAnimation {
                            showSaveSuccess = false
                        }
                    }
                } catch {
                    print("Помилка збереження: \(error)")
                }
            }
        }
    }
    
    private func copyToClipboard() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(reportText, forType: .string)
        
        withAnimation {
            showSaveSuccess = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation {
                showSaveSuccess = false
            }
        }
    }
    
    private func statusColor(_ status: HealthStatus) -> Color {
        switch status {
        case .good: return .green
        case .warning: return .orange
        case .critical: return .red
        }
    }
}

