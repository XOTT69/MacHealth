import Foundation
import Combine

class HardwareTestService: ObservableObject {
    @Published var results: [HardwareTestResult] = []
    @Published var isRunning = false
    @Published var currentTest: String = ""
    
    func runAllTests() {
        isRunning = true
        results = []
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.testDiskWrite()
            self?.testDiskRead()
            self?.testNetworkLatency()
            self?.testDNSSpeed()
            self?.testMemoryBandwidth()
            
            DispatchQueue.main.async {
                self?.isRunning = false
                self?.currentTest = ""
            }
        }
    }
    
    private func testDiskWrite() {
        updateStatus("Тест запису на диск...")
        
        let output = Shell.run("dd if=/dev/zero of=/tmp/machealth_test bs=1m count=256 2>&1 | tail -1")
        Shell.run("rm -f /tmp/machealth_test")
        
        var speed: Double = 0
        if output.contains("bytes/sec") || output.contains("MB/s") {
            // Парсимо швидкість
            let parts = output.components(separatedBy: " ")
            for (i, part) in parts.enumerated() {
                if part.contains("bytes/sec") && i > 0 {
                    let bytesPerSec = Double(parts[i-1].replacingOccurrences(of: "(", with: "")) ?? 0
                    speed = bytesPerSec / 1_000_000 // MB/s
                }
                if part == "MB/s" && i > 0 {
                    speed = Double(parts[i-1]) ?? 0
                }
            }
        }
        
        let level: HealthLevel
        if speed > 1000 { level = .excellent }
        else if speed > 500 { level = .good }
        else if speed > 100 { level = .warning }
        else { level = .critical }
        
        addResult(HardwareTestResult(
            testName: "💾 Швидкість запису",
            result: speed > 0 ? String(format: "%.0f МБ/с", speed) : "Не вдалося виміряти",
            value: speed,
            unit: "МБ/с",
            level: speed > 0 ? level : .unknown
        ))
    }
    
    private func testDiskRead() {
        updateStatus("Тест читання з диска...")
        
        // Створюємо тестовий файл
        Shell.run("dd if=/dev/zero of=/tmp/machealth_read_test bs=1m count=256 2>/dev/null")
        Shell.run("purge 2>/dev/null") // Очищаємо кеш
        
        let output = Shell.run("dd if=/tmp/machealth_read_test of=/dev/null bs=1m 2>&1 | tail -1")
        Shell.run("rm -f /tmp/machealth_read_test")
        
        var speed: Double = 0
        if let parenRange = output.range(of: "(") {
            let afterParen = String(output[parenRange.upperBound...])
            let numStr = afterParen.components(separatedBy: " ").first ?? "0"
            let bytes = Double(numStr) ?? 0
            speed = bytes / 1_000_000
        }
        
        let level: HealthLevel
        if speed > 2000 { level = .excellent }
        else if speed > 1000 { level = .good }
        else if speed > 300 { level = .warning }
        else { level = .critical }
        
        addResult(HardwareTestResult(
            testName: "💾 Швидкість читання",
            result: speed > 0 ? String(format: "%.0f МБ/с", speed) : "Не вдалося виміряти",
            value: speed,
            unit: "МБ/с",
            level: speed > 0 ? level : .unknown
        ))
    }
    
    private func testNetworkLatency() {
        updateStatus("Тест мережевої затримки...")
        
        let output = Shell.run("ping -c 5 8.8.8.8 2>/dev/null | tail -1")
        var avgMs: Double = 0
        
        if output.contains("/") {
            let parts = output.components(separatedBy: "/")
            if parts.count >= 5 {
                avgMs = Double(parts[4]) ?? 0
            }
        }
        
        let level: HealthLevel
        if avgMs > 0 && avgMs < 20 { level = .excellent }
        else if avgMs < 50 { level = .good }
        else if avgMs < 100 { level = .warning }
        else { level = .critical }
        
        addResult(HardwareTestResult(
            testName: "🌐 Мережева затримка",
            result: avgMs > 0 ? String(format: "%.1f мс", avgMs) : "Немає з'єднання",
            value: avgMs,
            unit: "мс",
            level: avgMs > 0 ? level : .critical
        ))
    }
    
    private func testDNSSpeed() {
        updateStatus("Тест DNS...")
        
        let start = Date()
        let _ = Shell.run("nslookup google.com 2>/dev/null")
        let elapsed = Date().timeIntervalSince(start) * 1000
        
        let level: HealthLevel
        if elapsed < 50 { level = .excellent }
        else if elapsed < 150 { level = .good }
        else if elapsed < 500 { level = .warning }
        else { level = .critical }
        
        addResult(HardwareTestResult(
            testName: "🔍 DNS відповідь",
            result: String(format: "%.0f мс", elapsed),
            value: elapsed,
            unit: "мс",
            level: level
        ))
    }
    
    private func testMemoryBandwidth() {
        updateStatus("Тест пам'яті...")
        
        let memGB = Double(Shell.sysctl("hw.memsize")) ?? 0
        let totalGB = memGB / 1_073_741_824
        
        // Простий тест - виділення та запис в пам'ять
        let start = Date()
        Shell.run("dd if=/dev/zero bs=1m count=512 2>/dev/null | md5 > /dev/null 2>&1")
        let elapsed = Date().timeIntervalSince(start)
        let bandwidth = elapsed > 0 ? 512.0 / elapsed : 0
        
        let level: HealthLevel
        if bandwidth > 5000 { level = .excellent }
        else if bandwidth > 2000 { level = .good }
        else if bandwidth > 500 { level = .warning }
        else { level = .critical }
        
        addResult(HardwareTestResult(
            testName: "🧠 Пропускна здатність RAM",
            result: bandwidth > 0 ? String(format: "%.0f МБ/с", bandwidth) : "—",
            value: bandwidth,
            unit: "МБ/с",
            level: bandwidth > 0 ? level : .unknown
        ))
    }
    
    private func updateStatus(_ status: String) {
        DispatchQueue.main.async { [weak self] in
            self?.currentTest = status
        }
    }
    
    private func addResult(_ result: HardwareTestResult) {
        DispatchQueue.main.async { [weak self] in
            self?.results.append(result)
        }
    }
}
