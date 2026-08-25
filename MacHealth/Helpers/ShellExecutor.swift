import Foundation

class ShellExecutor {
    
    /// Виконує shell-команду і повертає результат
    @discardableResult
    static func execute(_ command: String) -> String {
        let process = Process()
        let pipe = Pipe()
        
        process.standardOutput = pipe
        process.standardError = pipe
        process.arguments = ["-c", command]
        process.launchPath = "/bin/zsh"
        process.standardInput = nil
        
        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return ""
        }
        
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""
        return output.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    /// Виконує system_profiler для отримання даних про систему
    static func systemProfiler(dataType: String) -> String {
        return execute("system_profiler \(dataType) 2>/dev/null")
    }
    
    /// Отримує значення з ioreg
    static func ioreg(key: String, plane: String = "IOService") -> String {
        return execute("ioreg -r -c \(key) -p \(plane) 2>/dev/null")
    }
    
    /// Отримує значення sysctl
    static func sysctl(key: String) -> String {
        return execute("sysctl -n \(key) 2>/dev/null")
    }
}
