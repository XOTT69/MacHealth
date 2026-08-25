import Foundation

/// Безпечне виконання shell-команд
enum Shell {
    @discardableResult
    static func run(_ command: String) -> String {
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
        return (String(data: data, encoding: .utf8) ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    static func sysctl(_ key: String) -> String {
        run("sysctl -n \(key) 2>/dev/null")
    }
    
    static func systemProfiler(_ dataType: String) -> String {
        run("system_profiler \(dataType) 2>/dev/null")
    }
    
    static func grep(from text: String, pattern: String) -> String {
        let lines = text.components(separatedBy: "\n")
        for line in lines {
            if line.contains(pattern) {
                let parts = line.components(separatedBy: ":")
                if parts.count >= 2 {
                    return parts.dropFirst().joined(separator: ":").trimmingCharacters(in: .whitespaces)
                }
            }
        }
        return ""
    }
}
