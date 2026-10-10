import AppKit

enum DockPreferenceValue {
    static func booleanLiteral(_ raw: String) -> String? {
        switch raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "1", "true", "yes": return "true"
        case "0", "false", "no": return "false"
        default: return nil
        }
    }
}

/// Changes only three Dock preferences; never stops the Dock permanently.
@MainActor final class SystemDock: ObservableObject {
    @Published private(set) var hidden = false
    @Published private(set) var recoveryError: String?
    private var watchdog: Process?
    private let backupURL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support/ClothesDock/dock-backup.json")
    private let keys = ["autohide", "autohide-delay", "autohide-time-modifier"]
    private var original: [String: String] = [:]
    init() { recover() }
    @discardableResult private func run(_ executable: String, _ arguments: [String]) -> (Int32, String) {
        let p = Process(); p.executableURL = URL(fileURLWithPath: executable); p.arguments = arguments
        let out = Pipe(); p.standardOutput = out; p.standardError = out
        do { try p.run(); let data = out.fileHandleForReading.readDataToEndOfFile(); p.waitUntilExit(); return (p.terminationStatus, String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "") } catch { return (-1, error.localizedDescription) }
    }
    private func recover() {
        guard let data = try? Data(contentsOf: backupURL), let values = try? JSONDecoder().decode([String: String].self, from: data) else { return }
        original = values; restore()
    }
    func enable() throws {
        guard !hidden else { return }
        if !original.isEmpty {
            restore()
            guard original.isEmpty else { throw NSError(domain: "ClothesDock", code: 3, userInfo: [NSLocalizedDescriptionKey: recoveryError ?? "请先恢复原系统 Dock 设置。"]) }
        }
        for key in keys {
            let value = run("/usr/bin/defaults", ["read", "com.apple.dock", key]); original[key] = value.0 == 0 ? value.1 : "__absent__"
        }
        try FileManager.default.createDirectory(at: backupURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONEncoder().encode(original).write(to: backupURL, options: .atomic)
        guard let script = Bundle.main.url(forResource: "dock-watchdog", withExtension: "sh") else {
            try? FileManager.default.removeItem(at: backupURL)
            throw NSError(domain: "ClothesDock", code: 1, userInfo: [NSLocalizedDescriptionKey: "请运行打包后的 .app，恢复守护脚本缺失。"])
        }
        let p = Process(); p.executableURL = URL(fileURLWithPath: "/bin/sh")
        p.arguments = [script.path, String(ProcessInfo.processInfo.processIdentifier), backupURL.path] + keys.map { original[$0] ?? "__absent__" }
        p.standardOutput = FileHandle.nullDevice; p.standardError = FileHandle.nullDevice
        try p.run(); watchdog = p
        for (key, type, value) in [("autohide", "-bool", "true"), ("autohide-delay", "-float", "1000"), ("autohide-time-modifier", "-float", "0")] {
            guard run("/usr/bin/defaults", ["write", "com.apple.dock", key, type, value]).0 == 0 else { restore(); throw NSError(domain: "ClothesDock", code: 2, userInfo: [NSLocalizedDescriptionKey: "无法修改系统 Dock 设置，已尝试恢复。"]) }
        }
        hidden = true; _ = run("/usr/bin/killall", ["Dock"])
    }
    func restore() {
        guard !original.isEmpty else { recoveryError = nil; return }
        var failures: [String] = []
        for key in keys {
            guard let value = original[key] else { continue }
            if value == "__absent__" {
                let deletion = run("/usr/bin/defaults", ["delete", "com.apple.dock", key])
                if deletion.0 != 0 {
                    let readback = run("/usr/bin/defaults", ["read", "com.apple.dock", key])
                    if readback.0 == 0 { failures.append("\(key)：删除失败（\(deletion.0)）\(deletion.1.prefix(160))") }
                }
            } else {
                let restored: String
                if key == "autohide" {
                    guard let literal = DockPreferenceValue.booleanLiteral(value) else {
                        failures.append("\(key)：备份布尔值无效（\(value)）"); continue
                    }
                    restored = literal
                } else { restored = value }
                let result = run("/usr/bin/defaults", ["write", "com.apple.dock", key, key == "autohide" ? "-bool" : "-float", restored])
                if result.0 != 0 { failures.append("\(key)：写入失败（\(result.0)）\(result.1.prefix(160))") }
            }
        }
        guard failures.isEmpty else {
            recoveryError = "系统 Dock 恢复失败，备份已保留：\n" + failures.joined(separator: "\n")
            return
        }
        do {
            if FileManager.default.fileExists(atPath: backupURL.path) { try FileManager.default.removeItem(at: backupURL) }
        } catch {
            recoveryError = "系统 Dock 设置已恢复，但备份清理失败：\(error.localizedDescription)"
            return
        }
        watchdog?.terminate(); watchdog = nil
        original = [:]; hidden = false; recoveryError = nil
        _ = run("/usr/bin/killall", ["Dock"])
    }
}
