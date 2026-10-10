import SwiftUI
import ServiceManagement

struct SettingsView: View {
    @ObservedObject var model: DockModel
    @ObservedObject var systemDock: SystemDock
    @ViewState private var login = SMAppService.mainApp.status == .enabled
    var body: some View {
        Form {
            Section("晾晾 · ClothesDock") {
                Text("把熟悉的应用挂起来。").foregroundStyle(.secondary)
                Text("版本 \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "开发版")（构建 \(Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "—")）").font(.caption).foregroundStyle(.secondary)
                Picker("位置", selection: $model.config.edge) { Text("底部").tag(Edge.bottom); Text("顶部").tag(Edge.top); Text("左侧").tag(Edge.left); Text("右侧").tag(Edge.right) }
                HStack { Text("图标大小"); Slider(value: $model.config.iconSize, in: 32...80); Text("\(Int(model.config.iconSize)) px").monospacedDigit() }
                HStack { Text("离屏幕边缘"); Slider(value: $model.config.offset, in: 0...80); Text("\(Int(model.config.offset)) px") }
                Picker("绳子颜色", selection: $model.config.ropeColor) {
                    ForEach(RopeColor.allCases, id: \.self) { color in Text(color.label).tag(color) }
                }.pickerStyle(.segmented)
                HStack { Text("绳子粗细"); Slider(value: $model.config.ropeWidth, in: 0.5...6, step: 0.1); Text(String(format: "%.1f px", model.config.ropeWidth)).monospacedDigit() }
                Toggle("悬停放大与晾衣绳摆动", isOn: $model.config.magnify)
                Toggle("自动隐藏（靠近屏幕边缘显示）", isOn: $model.config.autoHide)
                if model.config.autoHide {
                    HStack { Text("显示触发距离"); Slider(value: $model.config.revealDistance, in: 1...80, step: 1); Text("\(Int(model.config.revealDistance)) px").monospacedDigit() }
                    Text("鼠标距当前屏幕边缘小于此距离才显示；显示后移入应用区可保持展开。").font(.caption).foregroundStyle(.secondary)
                }
                Toggle("在所有显示器显示", isOn: $model.config.allDisplays)
                Toggle("显示最近退出的应用", isOn: $model.config.showRecent)
                Toggle("登录时启动", isOn: $login).onChange(of: login) { _, value in model.login(value) }
                Text("⌃⌥D 显示 / 隐藏晾衣绳。").font(.caption).foregroundStyle(.secondary)
            }
            Section("系统 Dock") {
                if let error = systemDock.recoveryError { Text(error).foregroundStyle(.red) }
                Toggle("替代模式：隐藏普通桌面的系统 Dock", isOn: Binding(get: { systemDock.hidden }, set: { enable in
                    if enable { do { try systemDock.enable() } catch { model.error = error.localizedDescription } } else { systemDock.restore() }
                }))
                Text("此模式延迟普通桌面中的 Dock 弹出；App Exposé、Mission Control 等系统界面仍可能显示原 Dock。退出晾晾或异常退出后恢复原设置。").font(.caption).foregroundStyle(.secondary)
                HStack { Button("重新导入系统 Dock") { model.importDock() }; Button("添加应用 / 文件夹…") { choose() } }
            }
        }.formStyle(.grouped).frame(width: 540, height: 640)
        .alert("晾晾", isPresented: Binding(get: { model.error != nil }, set: { if !$0 { model.error = nil } })) { Button("好") { model.error = nil } } message: { Text(model.error ?? "") }
    }
    private func choose() {
        let panel = NSOpenPanel(); panel.canChooseFiles = true; panel.canChooseDirectories = true; panel.allowsMultipleSelection = true
        if panel.runModal() == .OK { model.pin(panel.urls) }
    }
}
