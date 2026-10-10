import SwiftUI
import UniformTypeIdentifiers

// Avoid the SDK 27 State macro sharing the property wrapper name.
typealias ViewState<Value> = SwiftUI.State<Value>

struct IconFrameKey: PreferenceKey {
    static var defaultValue: [CGRect] = []
    static func reduce(value: inout [CGRect], nextValue: () -> [CGRect]) { value.append(contentsOf: nextValue()) }
}

struct DockView: View {
    @ObservedObject var model: DockModel
    @ObservedObject var motion: ClotheslineMotion
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var vertical: Bool { model.config.edge.isVertical }
    var enabled: Bool { model.config.magnify && !reduceMotion && motion.isVisible }
    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: !enabled)) { timeline in
            Group {
                if vertical {
                    ScrollView(.vertical, showsIndicators: false) { VStack(spacing: 8) { tiles(date: timeline.date) }.padding(.vertical, 12) }
                } else {
                    ScrollView(.horizontal, showsIndicators: false) { HStack(alignment: .top, spacing: 8) { tiles(date: timeline.date) }.padding(.horizontal, 12) }
                }
            }
            .coordinateSpace(name: "clothesline")
        }
        .onPreferenceChange(IconFrameKey.self) { motion.updateIconFrames($0) }
        .onDrop(of: [.fileURL], isTargeted: nil) { providers in receiveFiles(providers) { model.pin($0) }; return true }
        .alert("晾晾", isPresented: Binding(get: { model.error != nil }, set: { if !$0 { model.error = nil } })) { Button("好") { model.error = nil } } message: { Text(model.error ?? "") }
    }
    @ViewBuilder func tiles(date: Date) -> some View {
        ForEach(model.items.filter { !$0.isTrash }) { item in hanging(item, date: date) }
        if model.config.showRecent {
            let recent = model.recent.filter { !model.items.contains($0) }
            if !recent.isEmpty {
                Color.clear.frame(width: vertical ? nil : 10, height: vertical ? 10 : nil)
                ForEach(recent) { item in hanging(item, date: date) }
            }
        }
            hanging(.trash, date: date)
    }
    func hanging(_ item: PinnedItem, date: Date) -> some View {
        HangingAppTile(model: model, motion: motion, item: item, date: date, enabled: enabled)
    }
}

struct HangingAppTile: View {
    @ObservedObject var model: DockModel
    @ObservedObject var motion: ClotheslineMotion
    let item: PinnedItem
    let date: Date
    let enabled: Bool
    @ViewState private var hovered = false
    var vertical: Bool { model.config.edge.isVertical }
    var body: some View {
        GeometryReader { geometry in
            let local = geometry.frame(in: .named("clothesline"))
            let t = motion.position(local: vertical ? local.midY : local.midX)
            let cross = 14 + motion.displacement(at: t, date: date, enabled: enabled)
            let right = model.config.edge == .right
            AppTile(model: model, item: item, hover: hovered,
                    angle: motion.angle(at: t, date: date, enabled: enabled), interaction: { launch in
                if enabled { motion.trigger(at: t, launch: launch) }
            })
            .position(x: vertical ? (right ? geometry.size.width - cross + 12 - (model.config.iconSize + 32) / 2 : cross - 12 + (model.config.iconSize + 32) / 2) : geometry.size.width / 2,
                      y: vertical ? geometry.size.height / 2 : cross - 12 + (model.config.iconSize + 32) / 2)
            .frame(width: geometry.size.width, height: geometry.size.height)
            .contentShape(Rectangle())
            .onContinuousHover { phase in
                let inside: Bool
                switch phase {
                case .active(let point):
                    let region = ClotheslineLayout.iconHoverRect(slot: geometry.size, iconSize: model.config.iconSize, position: t, edge: model.config.edge)
                    inside = region.contains(point)
                case .ended: inside = false
                }
                if hovered != inside { hovered = inside }
            }
            .background(GeometryReader { inner in
                let region = ClotheslineLayout.iconHoverRect(slot: geometry.size, iconSize: model.config.iconSize, position: t, edge: model.config.edge)
                let slot = inner.frame(in: .named("clothesline"))
                let icon = CGRect(x: slot.minX + region.minX, y: slot.minY + region.minY, width: region.width, height: region.height)
                Color.clear.preference(key: IconFrameKey.self, value: [icon])
            })
        }
        .frame(width: vertical ? model.config.iconSize + 112 : model.config.iconSize + 8,
               height: vertical ? model.config.iconSize + 8 : model.config.iconSize + 112)

    }
}

struct AppTile: View {
    @ObservedObject var model: DockModel
    let item: PinnedItem
    let hover: Bool
    let angle: Double
    let interaction: (Bool) -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        Button { interaction(true); model.open(item) } label: {
            let size = model.config.iconSize
            let vertical = model.config.edge.isVertical
            let right = model.config.edge == .right
            let width = vertical ? size + 32 : size + 8
            let height = vertical ? size + 8 : size + 32
            ZStack(alignment: .topLeading) {
                icon.position(x: vertical ? (right ? width - 16 - size / 2 : 16 + size / 2) : width / 2,
                              y: vertical ? height / 2 : 16 + size / 2)
                indicator.position(x: vertical ? (right ? 8 : width - 8) : width / 2,
                                   y: vertical ? height / 2 : 16 + size + 6)
                clip.rotationEffect(.degrees(vertical ? (right ? -90 : 90) : -6))
                    .position(x: vertical ? (right ? width - 12 : 12) : width / 2,
                              y: vertical ? height / 2 : 12)
                    .zIndex(1)
            }.frame(width: width, height: height)
                .rotationEffect(.degrees(angle), anchor: vertical ? (right ? UnitPoint(x: 1 - 12 / width, y: 0.5) : UnitPoint(x: 12 / width, y: 0.5)) : UnitPoint(x: 0.5, y: 12 / height))
                .contentShape(Rectangle())
        }.buttonStyle(.plain).focusEffectDisabled().help(item.name).accessibilityLabel(item.name)
        .animation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.5), value: hover)
        .onChange(of: hover) { _, inside in
            if inside { interaction(false) }
        }
        .contextMenu { menu }
        .onDrag { item.isTrash ? NSItemProvider() : NSItemProvider(object: item.path as NSString) }
        .onDrop(of: [.text, .fileURL], isTargeted: nil) { providers in
            if let p = providers.first, p.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                receiveFiles(providers) { urls in
                    if item.isTrash { model.trash(urls) }
                    else if urls.contains(where: { $0.pathExtension == "app" }) { model.pin(urls) } else { model.send(urls, to: item) }
                }
            } else if !item.isTrash, let p = providers.first {
                _ = p.loadObject(ofClass: NSString.self) { value, _ in
                    guard let path = value as? String else { return }
                    Task { @MainActor in
                        if !model.config.items.contains(where: { $0.path == path }) { model.config.pin(URL(fileURLWithPath: path)) }
                        if !model.config.items.contains(item) { model.config.pin(item.url) }
                        model.config.move(path, before: item.path)
                    }
                }
            }
            return true
        }
    }
    private var clip: some View {
        RoundedRectangle(cornerRadius: 2.5)
            .fill(Color(red: 0.95, green: 0.93, blue: 0.87))
            .overlay(RoundedRectangle(cornerRadius: 2.5).stroke(.black.opacity(0.35), lineWidth: 0.7))
            .overlay {
                Capsule().fill(Color(white: 0.45)).frame(width: 11, height: 2)
                    .overlay(Circle().stroke(Color(white: 0.35), lineWidth: 1).frame(width: 4, height: 4))
            }
            .frame(width: 9, height: 26)
            .shadow(color: .black.opacity(0.2), radius: 1, x: 1, y: 1)
            .allowsHitTesting(false)
    }
    private var icon: some View {
        Image(nsImage: model.icon(item)).resizable().interpolation(.high)
            .frame(width: model.config.iconSize, height: model.config.iconSize)
            .scaleEffect(hover && model.config.magnify ? 1.22 : 1, anchor: model.config.edge.isVertical ? (model.config.edge == .right ? .trailing : .leading) : .top)
    }
    private var indicator: some View {
        Circle().fill(model.app(item) == nil ? .clear : (model.app(item)?.isActive == true ? .blue : .primary.opacity(0.6))).frame(width: 4, height: 4)
    }
    @ViewBuilder var menu: some View {
        Button("打开 \(item.name)") { model.open(item) }
        if let app = model.app(item) {
            Button(app.isHidden ? "显示应用" : "隐藏应用") { if app.isHidden { app.unhide() } else { app.hide() } }
            Button("退出应用") { app.terminate() }
            Button("强制退出…") {
                let alert = NSAlert(); alert.messageText = "强制退出 \(item.name)？"; alert.informativeText = "未保存的内容可能丢失。"; alert.addButton(withTitle: "取消"); alert.addButton(withTitle: "强制退出")
                if alert.runModal() == .alertSecondButtonReturn { app.forceTerminate() }
            }
        }
        if !item.isTrash, !item.isApp, (try? item.url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true {
            Menu("文件夹内容") {
                let files = (try? FileManager.default.contentsOfDirectory(at: item.url, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles])) ?? []
                ForEach(files.sorted(by: { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }).prefix(80), id: \.path) { url in
                    Button(url.lastPathComponent) { NSWorkspace.shared.open(url) }
                }
                if files.count > 80 { Button("在 Finder 查看全部…") { model.open(item) } }
            }
        }
        Divider()
        if item.isTrash { Button("清倒废纸篓…") { model.emptyTrash() } }
        else {
            if model.config.items.contains(item) { Button("从晾衣绳取下") { model.unpin(item) } }
            else { Button("固定到晾衣绳") { model.pin([item.url]) } }
            Button("在 Finder 中显示") { NSWorkspace.shared.activateFileViewerSelecting([item.url]) }
        }
    }
}
func receiveFiles(_ providers: [NSItemProvider], completion: @escaping @MainActor ([URL]) -> Void) {
    for provider in providers {
        provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
            let url: URL?
            if let data = item as? Data { url = URL(dataRepresentation: data, relativeTo: nil) }
            else if let value = item as? URL { url = value }
            else { url = nil }
            if let url, url.isFileURL { Task { @MainActor in completion([url]) } }
        }
    }
}
