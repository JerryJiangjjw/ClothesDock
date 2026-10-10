import Foundation
import Testing
@testable import ClothesDock

struct ConfigurationTests {
    @Test func testReorderBothDirectionsAndIgnoreInvalidTargets() {
        var config = Configuration(items: ["/a.app", "/b.app", "/c.app"].map { PinnedItem(path: $0) })
        config.move("/a.app", before: "/c.app")
        #expect(config.items.map(\.path) == ["/b.app", "/a.app", "/c.app"])
        config.move("/c.app", before: "/b.app")
        #expect(config.items.map(\.path) == ["/c.app", "/b.app", "/a.app"])
        let before = config
        config.move("/a.app", before: "/missing.app")
        config.move("/a.app", before: "/a.app")
        #expect(config == before)
    }
    @Test func testPinNormalizesAndDeduplicatesPaths() {
        var config = Configuration()
        config.pin(URL(fileURLWithPath: "/Applications/../Applications/A.app"))
        config.pin(URL(fileURLWithPath: "/Applications/A.app"))
        #expect(config.items.map(\.path) == ["/Applications/A.app"])
    }
    @Test func testAtomicSettingsRoundtripAndCorruptFileFallback() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = ConfigurationStore(url: root.appendingPathComponent("config.json"))
        #expect(store.load() == nil)
        var config = Configuration(); config.pin(URL(fileURLWithPath: "/Applications/A.app")); config.edge = .left; config.autoHide = true; config.iconSize = 72
        try store.save(config)
        #expect(store.load() == config)
        try Data("invalid".utf8).write(to: store.url)
        #expect(store.load() == nil)
    }
}
