import Foundation

/// Результат локальної системної команди. Дані не передаються за межі Mac.
struct CommandResult {
    let output: String
    let exitCode: Int32
    let timedOut: Bool

    var succeeded: Bool { exitCode == 0 && !timedOut }
}

/// Запускає лише явний виконуваний файл та окремо передані аргументи.
/// Це унеможливлює shell-інʼєкцію і не дає великому виводу заблокувати застосунок.
enum Shell {
    static func run(
        _ executable: String,
        arguments: [String] = [],
        timeout: TimeInterval = 20
    ) -> CommandResult {
        let process = Process()
        let standardOutput = Pipe()
        let standardError = Pipe()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.standardOutput = standardOutput
        process.standardError = standardError
        process.standardInput = nil

        do {
            try process.run()
        } catch {
            return CommandResult(output: "", exitCode: -1, timedOut: false)
        }

        let outputBox = DataBox()
        let group = DispatchGroup()
        collect(from: standardOutput.fileHandleForReading, into: outputBox, group: group)
        collect(from: standardError.fileHandleForReading, into: outputBox, group: group)

        let deadline = Date().addingTimeInterval(timeout)
        var timedOut = false
        while process.isRunning && Date() < deadline {
            Thread.sleep(forTimeInterval: 0.03)
        }
        if process.isRunning {
            timedOut = true
            process.terminate()
        }
        process.waitUntilExit()
        group.wait()

        let text = String(data: outputBox.data, encoding: .utf8) ?? ""
        return CommandResult(
            output: text.trimmingCharacters(in: .whitespacesAndNewlines),
            exitCode: process.terminationStatus,
            timedOut: timedOut
        )
    }

    static func sysctl(_ key: String) -> String {
        run("/usr/sbin/sysctl", arguments: ["-n", key]).output
    }

    static func systemProfiler(_ dataType: String) -> String {
        run("/usr/sbin/system_profiler", arguments: [dataType], timeout: 30).output
    }

    static func defaultNetworkInterface() -> String {
        let route = run("/sbin/route", arguments: ["-n", "get", "default"]).output
        return route.components(separatedBy: .newlines)
            .first { $0.trimmingCharacters(in: .whitespaces).hasPrefix("interface:") }?
            .split(separator: ":", maxSplits: 1)
            .last?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    static func grep(from text: String, pattern: String) -> String {
        for line in text.components(separatedBy: .newlines) where line.contains(pattern) {
            let parts = line.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false)
            if parts.count == 2 {
                return String(parts[1]).trimmingCharacters(in: .whitespaces)
            }
        }
        return ""
    }

    private static func collect(from handle: FileHandle, into box: DataBox, group: DispatchGroup) {
        group.enter()
        DispatchQueue.global(qos: .utility).async {
            box.append(handle.readDataToEndOfFile())
            group.leave()
        }
    }
}

private final class DataBox {
    private let lock = NSLock()
    private var stored = Data()

    var data: Data {
        lock.lock()
        defer { lock.unlock() }
        return stored
    }

    func append(_ data: Data) {
        lock.lock()
        stored.append(data)
        lock.unlock()
    }
}
