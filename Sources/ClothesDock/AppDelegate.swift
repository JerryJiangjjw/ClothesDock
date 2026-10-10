import AppKit
import SwiftUI
import Combine
import Carbon

final class DockPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}
final class RopePanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}
final class DockHostingView: NSHostingView<DockView> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}
@MainActor final class AppDelegate: NSObject, NSApplicationDelegate {
    private var model: DockModel!
    private var status: NSStatusItem!
    private var panels: [DockPanel] = []
    private var ropes: [RopePanel] = []
    private var motions: [ClotheslineMotion] = []
    private var screens: [NSScreen] = []
    private var settingsWindow: NSWindow?
    private var subscriptions = Set<AnyCancellable>()
    private var timer: Timer?
    private var manualHidden = false
    private var hotkeys: [EventHotKeyRef] = []
    private var eventHandler: EventHandlerRef?
    func applicationDidFinishLaunching(_ notification: Notification) {
        if NSRunningApplication.runningApplications(withBundleIdentifier: Bundle.main.bundleIdentifier ?? "local.clothesdock").contains(where: { $0.processIdentifier != ProcessInfo.processInfo.processIdentifier }) { NSApp.terminate(nil); return }
        NSApp.setActivationPolicy(.accessory)
        let firstLaunch = ConfigurationStore().load() == nil
        model = DockModel()
        model.settingsAction = { [weak self] in self?.showSettings() }
        setupStatus(); rebuildPanels(); registerShortcuts()
        model.$config.dropFirst().debounce(for: .milliseconds(100), scheduler: RunLoop.main).sink { [weak self] _ in self?.rebuildPanels() }.store(in: &subscriptions)
        model.$running.dropFirst().receive(on: RunLoop.main).sink { [weak self] _ in self?.layoutPanels() }.store(in: &subscriptions)
        NotificationCenter.default.addObserver(self, selector: #selector(screenChanged), name: NSApplication.didChangeScreenParametersNotification, object: nil)
        timer = Timer.scheduledTimer(withTimeInterval: 0.15, repeats: true) { [weak self] _ in Task { @MainActor in self?.updateVisibility() } }
        if firstLaunch || CommandLine.arguments.contains("--settings") { showSettings() }
    }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool { showSettings(); return true }
    func applicationWillTerminate(_ notification: Notification) {
        model?.systemDock.restore(); timer?.invalidate()
        hotkeys.forEach { UnregisterEventHotKey($0) }
        if let eventHandler { RemoveEventHandler(eventHandler) }
    }
    private func setupStatus() {
        status = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        status.button?.image = NSImage(systemSymbolName: "hanger", accessibilityDescription: "晾晾")
        let menu = NSMenu()
        for (title, action, key) in [("设置…", #selector(showSettings), ","), ("显示 / 隐藏晾衣绳", #selector(toggleDock), "d"), ("恢复系统 Dock", #selector(restoreDock), ""), ("退出晾晾", #selector(quit), "q")] {
            let item = NSMenuItem(title: title, action: action, keyEquivalent: key); item.target = self; menu.addItem(item)
        }
        status.menu = menu
    }
    @objc private func screenChanged() { rebuildPanels() }
    private func rebuildPanels() {
        panels.forEach { $0.orderOut(nil) }; ropes.forEach { $0.orderOut(nil) }
        panels = []; ropes = []; motions = []
        screens = model.config.allDisplays ? NSScreen.screens : Array(NSScreen.screens.prefix(1))
        for _ in screens {
            let motion = ClotheslineMotion(); motion.edge = model.config.edge
            let rope = RopePanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
            rope.level = NSWindow.Level(rawValue: NSWindow.Level.statusBar.rawValue - 1)
            rope.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
            rope.backgroundColor = .clear; rope.isOpaque = false; rope.hasShadow = false
            rope.ignoresMouseEvents = true; rope.hidesOnDeactivate = false; rope.isReleasedWhenClosed = false
            rope.contentView = NSHostingView(rootView: ClotheslineView(model: model, motion: motion))
            ropes.append(rope); motions.append(motion)
            let panel = DockPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
            panel.isFloatingPanel = true; panel.level = .statusBar
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
            panel.backgroundColor = .clear; panel.isOpaque = false; panel.hasShadow = false; panel.hidesOnDeactivate = false; panel.isReleasedWhenClosed = false
            panel.contentView = DockHostingView(rootView: DockView(model: model, motion: motion))
            panels.append(panel)
        }
        layoutPanels(); updateVisibility()
        ropes.forEach { $0.orderFrontRegardless() }; panels.forEach { $0.orderFrontRegardless() }
    }
    private func layoutPanels() {
        guard let model else { return }
        let config = model.config
        let recentCount = config.showRecent ? model.recent.filter { !model.items.contains($0) }.count : 0
        let count = model.items.count + recentCount
        let length = max(48, CGFloat(count) * (config.iconSize + 16) + 16 + (recentCount > 0 ? 18 : 0))
        for (index, screen) in screens.enumerated() {
            let panel = panels[index]
            let frame = ClotheslineLayout.dockFrame(screen: screen.frame, menuBarTop: screen.visibleFrame.maxY, edge: config.edge, iconSize: config.iconSize, offset: config.offset, length: length)
            let ropeFrame = ClotheslineLayout.ropeFrame(screen: screen.frame, menuBarTop: screen.visibleFrame.maxY, dock: frame, edge: config.edge)
            motions[index].dockFrame = frame; motions[index].ropeFrame = ropeFrame
            panel.setFrame(frame, display: true); ropes[index].setFrame(ropeFrame, display: true)
        }
    }
    private func updateVisibility() {
        guard let model else { return }
        let mouse = NSEvent.mouseLocation
        for (index, screen) in screens.enumerated() {
            let panel = panels[index]
            let nearEdge = ClotheslineLayout.nearEdge(mouse: mouse, screen: screen.frame, edge: model.config.edge, distance: model.config.revealDistance)
            let within = panel.frame.insetBy(dx: -14, dy: -14).contains(mouse)
            let show = !manualHidden && (!model.config.autoHide || nearEdge || (panel.alphaValue > 0 && within))
            panel.alphaValue = show ? 1 : 0; panel.ignoresMouseEvents = !show
            ropes[index].alphaValue = show ? 1 : 0
            if motions[index].isVisible != show { motions[index].isVisible = show }
        }
    }
    @objc func showSettings() {
        if settingsWindow == nil {
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 540, height: 640), styleMask: [.titled, .closable, .miniaturizable], backing: .buffered, defer: false)
            window.title = "晾晾 · 设置"; window.isReleasedWhenClosed = false
            window.contentView = NSHostingView(rootView: SettingsView(model: model, systemDock: model.systemDock)); window.center(); settingsWindow = window
        }
        NSApp.activate(ignoringOtherApps: true); settingsWindow?.makeKeyAndOrderFront(nil)
    }
    @objc func toggleDock() { manualHidden.toggle(); updateVisibility() }
    @objc private func restoreDock() { model.systemDock.restore() }
    @objc private func quit() { NSApp.terminate(nil) }
    private func registerShortcuts() {
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, event, context in
            guard let event, let context else { return OSStatus(eventNotHandledErr) }
            var id = EventHotKeyID()
            GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID), nil, MemoryLayout<EventHotKeyID>.size, nil, &id)
            let delegate = Unmanaged<AppDelegate>.fromOpaque(context).takeUnretainedValue()
            let keyID = id.id
            Task { @MainActor in if keyID == 1 { delegate.toggleDock() } }
            return noErr
        }, 1, &spec, Unmanaged.passUnretained(self).toOpaque(), &eventHandler)
        for (key, id) in [(UInt32(kVK_ANSI_D), UInt32(1))] {
            var ref: EventHotKeyRef?
            let result = RegisterEventHotKey(key, UInt32(controlKey | optionKey), EventHotKeyID(signature: 0x434C444B, id: id), GetApplicationEventTarget(), 0, &ref)
            if result == noErr, let ref { hotkeys.append(ref) }
            else { model.error = "全局快捷键被其他应用占用，可使用菜单栏控制。" }
        }
    }
}
