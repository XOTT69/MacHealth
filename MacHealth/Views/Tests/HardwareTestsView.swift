import SwiftUI

struct HardwareTestsView: View {
    @ObservedObject var service: HardwareTestService
    @State private var showTestConfirmation = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                HStack {
                    Text("Hardware тести")
                        .font(.largeTitle.bold())
                    Spacer()
                    Button(action: { showTestConfirmation = true }) {
                        Label(service.isRunning ? "Виконується..." : "Запустити всі тести", systemImage: "play.fill")
                            .font(.headline)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(service.isRunning)
                }
                
                if service.isRunning {
                    VStack(spacing: 8) {
                        ProgressView()
                        Text(service.currentTest)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(20)
                    .background(RoundedRectangle(cornerRadius: 12).fill(.blue.opacity(0.05)))
                }
                
                if !service.results.isEmpty {
                    VStack(spacing: 12) {
                        ForEach(service.results) { result in
                            HStack(spacing: 12) {
                                Image(systemName: result.level.icon)
                                    .font(.title2)
                                    .foregroundStyle(Color.statusColor(result.level))
                                    .frame(width: 30)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(result.testName)
                                        .font(.body.bold())
                                    Text(result.result)
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                                
                                Spacer()
                                
                                VStack(alignment: .trailing) {
                                    Text(result.level.rawValue)
                                        .font(.caption.bold())
                                        .foregroundStyle(Color.statusColor(result.level))
                                }
                            }
                            .padding(16)
                            .background(RoundedRectangle(cornerRadius: 12).fill(Color.statusColor(result.level).opacity(0.03)))
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.statusColor(result.level).opacity(0.15), lineWidth: 1))
                        }
                    }
                } else if !service.isRunning {
                    VStack(spacing: 12) {
                        Image(systemName: "wrench.and.screwdriver")
                            .font(.system(size: 48))
                            .foregroundStyle(.secondary)
                        Text("Натисніть «Запустити всі тести»")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                        Text("Буде виконано тестування диску, мережі та пам'яті")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    .frame(maxWidth: .infinity, minHeight: 200)
                }
            }
            .padding(24)
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .alert("Запустити апаратні тести?", isPresented: $showTestConfirmation) {
            Button("Скасувати", role: .cancel) {}
            Button("Запустити") { service.runAllTests() }
        } message: {
            Text("Тест короткочасно запише 128 МБ у тимчасову теку й виконає мережеві запити. Дані користувача не змінюються.")
        }
    }
}
