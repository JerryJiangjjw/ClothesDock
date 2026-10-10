import Foundation
import Testing
@testable import ClothesDock

struct ClotheslineTests {
    @Test func topLayoutRespectsMenuBarOnOffsetDisplay() {
        let screen = CGRect(x: -1920, y: 400, width: 1920, height: 1080)
        let dock = ClotheslineLayout.dockFrame(screen: screen, menuBarTop: 1456, edge: .top, iconSize: 52, offset: 8, length: 800)
        #expect(dock.maxY == 1448)
        #expect(dock.midX == screen.midX)
        let rope = ClotheslineLayout.ropeFrame(screen: screen, menuBarTop: 1456, dock: dock, edge: .top)
        #expect(rope.minX == screen.minX)
        #expect(rope.maxX == screen.maxX)
        #expect(rope.minY == dock.minY)
        #expect(rope.maxY == dock.maxY)
    }
    @Test func allEdgesKeepIconsWithinDisplayAndExtendRopeToEnds() {
        let screen = CGRect(x: 300, y: -900, width: 1440, height: 900)
        for edge in Edge.allCases {
            let dock = ClotheslineLayout.dockFrame(screen: screen, menuBarTop: -24, edge: edge, iconSize: 80, offset: 8, length: 4000)
            #expect(screen.contains(dock))
            let rope = ClotheslineLayout.ropeFrame(screen: screen, menuBarTop: -24, dock: dock, edge: edge)
            if edge.isVertical { #expect(rope.minY == screen.minY); #expect(rope.maxY == -24) }
            else { #expect(rope.minX == screen.minX); #expect(rope.maxX == screen.maxX) }
        }
    }
    @Test @MainActor func curveAndMotionKeepEndpointsAnchoredAndRespectReducedMotion() {
        let motion = ClotheslineMotion()
        motion.trigger(at: 0.5)
        let date = motion.pulse.addingTimeInterval(0.15)
        #expect(motion.displacement(at: 0, date: date, enabled: true) == 0)
        #expect(abs(motion.displacement(at: 1, date: date, enabled: true)) < 0.00001)
        #expect(ClotheslineLayout.sag(at: 0.5) == 42)
        #expect(ClotheslineLayout.sag(at: 0.25) == ClotheslineLayout.sag(at: 0.75))
        #expect(motion.angle(at: 0.5, date: date, enabled: false) == 0)
        #expect(motion.displacement(at: 0.5, date: date, enabled: false) == 42)
        #expect(abs(motion.angle(at: 0.5, date: date, enabled: true)) > 10)
    }
    @Test func topSettingSurvivesCoding() throws {
        var config = Configuration(); config.edge = .top
        let decoded = try JSONDecoder().decode(Configuration.self, from: JSONEncoder().encode(config))
        #expect(decoded.edge == .top)
    }
}
