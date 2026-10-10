import Foundation
import Testing
@testable import ClothesDock

struct AppearanceTests {
    @Test func oldConfigurationKeepsPinsAndPreferencesWithNewDefaults() throws {
        let legacy = Data(#"{"items":[{"path":"/Applications/Example.app"}],"iconSize":61,"edge":"top","autoHide":true,"allDisplays":false,"magnify":false,"showRecent":false,"offset":23}"#.utf8)
        let config = try JSONDecoder().decode(Configuration.self, from: legacy)
        #expect(config.items.map(\.path) == ["/Applications/Example.app"])
        #expect(config.iconSize == 61 && config.edge == .top && config.offset == 23)
        #expect(config.autoHide && !config.allDisplays && !config.magnify && !config.showRecent)
        #expect(config.ropeWidth == 1.8 && config.ropeColor == .gray && config.revealDistance == 12)
    }
    @Test func appearanceAndRevealSettingsPersist() throws {
        for color in RopeColor.allCases {
            var config = Configuration(); config.ropeColor = color; config.ropeWidth = 4.2; config.revealDistance = 35
            let result = try JSONDecoder().decode(Configuration.self, from: JSONEncoder().encode(config))
            #expect(result == config)
        }
    }
    @Test func revealRequiresPhysicalEdgeOnTheCorrectScreen() {
        let screen = CGRect(x: -1440, y: -200, width: 1440, height: 1000)
        for (edge, near, far) in [
            (Edge.top, CGPoint(x: -720, y: 790), CGPoint(x: -720, y: 780)),
            (.bottom, CGPoint(x: -720, y: -190), CGPoint(x: -720, y: -180)),
            (.left, CGPoint(x: -1430, y: 300), CGPoint(x: -1420, y: 300)),
            (.right, CGPoint(x: -10, y: 300), CGPoint(x: -20, y: 300))
        ] {
            #expect(ClotheslineLayout.nearEdge(mouse: near, screen: screen, edge: edge, distance: 12))
            #expect(!ClotheslineLayout.nearEdge(mouse: far, screen: screen, edge: edge, distance: 12))
        }
        #expect(!ClotheslineLayout.nearEdge(mouse: CGPoint(x: 10, y: 790), screen: screen, edge: .top, distance: 12))
        #expect(!ClotheslineLayout.nearEdge(mouse: CGPoint(x: -720, y: 801), screen: screen, edge: .top, distance: 12))
        #expect(ClotheslineLayout.nearEdge(mouse: CGPoint(x: -720, y: 788), screen: screen, edge: .top, distance: 12))
    }
}
