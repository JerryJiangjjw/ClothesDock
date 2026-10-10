import AppKit

struct PinnedItem: Codable, Identifiable, Equatable {
    var id: String { path }
    var path: String
    var url: URL { URL(fileURLWithPath: path) }
    static var trash: PinnedItem { PinnedItem(path: FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".Trash").path) }
    var isTrash: Bool { path == Self.trash.path }
    var isApp: Bool { url.pathExtension == "app" }
    var name: String { if isTrash { return "废纸篓" }; return FileManager.default.displayName(atPath: path).replacingOccurrences(of: ".app", with: "") }
}
enum Edge: String, Codable, CaseIterable { case bottom, top, left, right }
enum RopeColor: String, Codable, CaseIterable { case black, white, gray, brown }
struct Configuration: Codable, Equatable {
    var items: [PinnedItem] = []
    var iconSize: Double = 52
    var edge: Edge = .bottom
    var autoHide = false
    var allDisplays = true
    var magnify = true
    var showRecent = true
    var offset: Double = 8
    var ropeWidth: Double = 1.8
    var ropeColor: RopeColor = .gray
    var revealDistance: Double = 12
    mutating func pin(_ url: URL) {
        let item = PinnedItem(path: url.standardizedFileURL.path)
        if !items.contains(item) { items.append(item) }
    }
    mutating func move(_ path: String, before target: String) {
        guard path != target, let from = items.firstIndex(where: { $0.path == path }), items.contains(where: { $0.path == target }) else { return }
        let item = items.remove(at: from)
        if let to = items.firstIndex(where: { $0.path == target }) { items.insert(item, at: to) }
    }
}
// Missing new keys use defaults without discarding an existing user's pinned items.
extension Configuration {
    enum CodingKeys: String, CodingKey {
        case items, iconSize, edge, autoHide, allDisplays, magnify, showRecent, offset
        case ropeWidth, ropeColor, revealDistance
    }
    init(from decoder: Decoder) throws {
        self.init()
        let values = try decoder.container(keyedBy: CodingKeys.self)
        items = try values.decodeIfPresent([PinnedItem].self, forKey: .items) ?? items
        iconSize = try values.decodeIfPresent(Double.self, forKey: .iconSize) ?? iconSize
        edge = try values.decodeIfPresent(Edge.self, forKey: .edge) ?? edge
        autoHide = try values.decodeIfPresent(Bool.self, forKey: .autoHide) ?? autoHide
        allDisplays = try values.decodeIfPresent(Bool.self, forKey: .allDisplays) ?? allDisplays
        magnify = try values.decodeIfPresent(Bool.self, forKey: .magnify) ?? magnify
        showRecent = try values.decodeIfPresent(Bool.self, forKey: .showRecent) ?? showRecent
        offset = try values.decodeIfPresent(Double.self, forKey: .offset) ?? offset
        ropeWidth = min(6, max(0.5, try values.decodeIfPresent(Double.self, forKey: .ropeWidth) ?? ropeWidth))
        ropeColor = try values.decodeIfPresent(RopeColor.self, forKey: .ropeColor) ?? ropeColor
        revealDistance = min(80, max(1, try values.decodeIfPresent(Double.self, forKey: .revealDistance) ?? revealDistance))
    }
}
final class ConfigurationStore {
    let url: URL
    init(url: URL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support/ClothesDock/config.json")) { self.url = url }
    func load() -> Configuration? { guard let data = try? Data(contentsOf: url) else { return nil }; return try? JSONDecoder().decode(Configuration.self, from: data) }
    func save(_ value: Configuration) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONEncoder().encode(value).write(to: url, options: .atomic)
    }
    static func importDock() -> [PinnedItem] {
        let defaults = UserDefaults(suiteName: "com.apple.dock")
        let tiles = (defaults?.array(forKey: "persistent-apps") ?? []) + (defaults?.array(forKey: "persistent-others") ?? [])
        var config = Configuration()
        for case let tile as [String: Any] in tiles {
            guard let data = tile["tile-data"] as? [String: Any], let file = data["file-data"] as? [String: Any], let path = file["_CFURLString"] as? String, let url = URL(string: path), url.isFileURL else { continue }
            config.pin(url)
        }
        if config.items.isEmpty {
            for path in ["/System/Library/CoreServices/Finder.app", "/Applications/Safari.app", "/System/Applications/Mail.app", "/System/Applications/System Settings.app"] where FileManager.default.fileExists(atPath: path) { config.pin(URL(fileURLWithPath: path)) }
        }
        return config.items
    }
}
