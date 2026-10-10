import AppKit
import Combine
import ServiceManagement

@MainActor final class DockModel: ObservableObject {
    @Published var config: Configuration { didSet { persist() } }
    @Published var running: [NSRunningApplication] = []
    @Published var recent: [PinnedItem] = []
    @Published var error: String?
    let systemDock = SystemDock()
    let store = ConfigurationStore()
    private var icons: [String: NSImage] = [:]
    var settingsAction: () -> Void = {}
    private var observers: [NSObjectProtocol] = []
    init() {
        config = store.load() ?? Configuration(items: ConfigurationStore.importDock())
        persist()
        refresh()
        let center = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.didLaunchApplicationNotification, NSWorkspace.didTerminateApplicationNotification, NSWorkspace.didActivateApplicationNotification, NSWorkspace.didHideApplicationNotification, NSWorkspace.didUnhideApplicationNotification] {
            observers.append(center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in Task { @MainActor in self?.refresh() } })
        }
    }
    private func persist() { do { try store.save(config) } catch { self.error = "保存设置失败：\(error.localizedDescription)" } }
    func refresh() {
        let next = NSWorkspace.shared.runningApplications.filter { $0.activationPolicy == .regular && $0.processIdentifier != ProcessInfo.processInfo.processIdentifier }
        for previous in running where !next.contains(where: { $0.bundleURL == previous.bundleURL }) {
            if let url = previous.bundleURL { recent.removeAll { $0.path == url.path }; recent.insert(PinnedItem(path: url.path), at: 0) }
        }
        recent = Array(recent.prefix(5)); running = next
    }
    var items: [PinnedItem] {
        var items = config.items.filter { !$0.isTrash }
        for app in running { if let url = app.bundleURL, !items.contains(where: { $0.path == url.path }) { items.append(PinnedItem(path: url.path)) } }
        return items + [.trash]
    }
    func icon(_ item: PinnedItem) -> NSImage {
        if let cached = icons[item.path] { return cached }
        let image = item.isTrash
            ? (NSImage(contentsOfFile: "/System/Library/CoreServices/Dock.app/Contents/Resources/trashempty@2x.png") ?? NSImage(systemSymbolName: "trash", accessibilityDescription: "废纸篓") ?? NSWorkspace.shared.icon(forFile: item.path))
            : NSWorkspace.shared.icon(forFile: item.path)
        icons[item.path] = image
        return image
    }
    func app(_ item: PinnedItem) -> NSRunningApplication? { running.first { $0.bundleURL?.standardizedFileURL.path == item.path } }
    func open(_ item: PinnedItem) {
        if item.isTrash { NSWorkspace.shared.open(item.url); return }
        guard FileManager.default.fileExists(atPath: item.path) else { error = "找不到 \(item.path)，可从右键菜单移除。"; return }
        if let app = app(item) {
            app.activate(options: [.activateAllWindows])
        } else if item.isApp {
            NSWorkspace.shared.openApplication(at: item.url, configuration: .init()) { [weak self] _, error in
                if let error { Task { @MainActor in self?.error = error.localizedDescription } }
            }
        } else { NSWorkspace.shared.open(item.url) }
    }
    func pin(_ urls: [URL]) { for url in urls where FileManager.default.fileExists(atPath: url.path) { config.pin(url) } }
    func unpin(_ item: PinnedItem) { config.items.removeAll { $0.id == item.id } }
    func importDock() { config.items = ConfigurationStore.importDock() }
    func send(_ urls: [URL], to item: PinnedItem) {
        if item.isApp {
            NSWorkspace.shared.open(urls, withApplicationAt: item.url, configuration: .init()) { [weak self] _, error in
                if let error { Task { @MainActor in self?.error = error.localizedDescription } }
            }
        } else { pin(urls) }
    }
    func trash(_ urls: [URL]) {
        NSWorkspace.shared.recycle(urls) { [weak self] _, error in
            if let error { Task { @MainActor in self?.error = error.localizedDescription } }
        }
    }
    func emptyTrash() {
        let alert = NSAlert(); alert.messageText = "永久清倒废纸篓？"; alert.informativeText = "这将由 Finder 清倒所有磁盘上的废纸篓，操作不能撤销。"; alert.addButton(withTitle: "取消"); alert.addButton(withTitle: "清倒")
        guard alert.runModal() == .alertSecondButtonReturn else { return }
        var details: NSDictionary?
        NSAppleScript(source: "tell application \"Finder\" to empty trash")?.executeAndReturnError(&details)
        if let details { error = "清倒失败：\(details[NSAppleScript.errorMessage] ?? details)。请允许自动化控制 Finder，或在 Finder 中操作。" }
    }
    func login(_ enable: Bool) {
        do { if enable { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() } }
        catch { self.error = "登录启动设置失败：\(error.localizedDescription)" }
    }
}
