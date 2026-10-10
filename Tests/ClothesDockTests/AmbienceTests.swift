import Foundation
import Testing
@testable import ClothesDock

struct AmbienceTests {
    @Test func iconCoordinatesUseThePhysicalScreenOnOffsetDisplays() {
        let screen = CGRect(x: -1920, y: 400, width: 1920, height: 1080)
        let dock = CGRect(x: -1300, y: 420, width: 680, height: 164)
        let icon = CGRect(x: 80, y: 52, width: 52, height: 52)
        let result = AmbienceLayout.iconOnScreen(icon, dock: dock, screen: screen)
        #expect(result == CGRect(x: 700, y: 948, width: 52, height: 52))
    }
    @Test func butterflyFullyEntersAndExitsEveryPhysicalScreenEdge() {
        let size = CGSize(width: 1920, height: 1080)
        let screen = CGRect(origin: .zero, size: size)
        let icon = CGRect(x: 730, y: 850, width: 64, height: 64)
        for edge in Edge.allCases {
            for fromStart in [true, false] {
                let flight = ButterflyFlight(start: Date(), iconFrame: icon, screenSize: size, edge: edge, fromStart: fromStart)
                for point in [flight.position(at: 0), flight.position(at: flight.duration)] {
                    // Includes wings and shadow, not just the sprite center.
                    #expect(!screen.intersects(CGRect(x: point.x - 40, y: point.y - 40, width: 80, height: 80)))
                }
                #expect(flight.position(at: flight.inDuration) == flight.target)
                let takeoff = flight.position(at: flight.inDuration + flight.restDuration)
                #expect(abs(takeoff.x - flight.target.x) < 0.0001)
                #expect(abs(takeoff.y - flight.target.y) < 0.0001)
                #expect(flight.inDuration >= 1.8 && flight.outDuration >= 1.8)
            }
        }
    }
    @Test func windLinesAndLeavesTravelOutsideBeforeCleanup() {
        let start = Date(), size = CGSize(width: 1440, height: 900)
        let screen = CGRect(origin: .zero, size: size)
        for edge in Edge.allCases {
            for fromStart in [true, false] {
                let gust = GustState(start: start, fromStart: fromStart)
                for date in [start, start.addingTimeInterval(GustState.duration)] {
                    let point = gust.center(size: size, edge: edge, cross: 300, date: date)
                    let sprite = CGRect(x: point.x - 170, y: point.y - 170, width: 340, height: 340)
                    #expect(!screen.intersects(sprite))
                }
                #expect(gust.isActive(at: start.addingTimeInterval(1)))
                #expect(!gust.isActive(at: start.addingTimeInterval(GustState.duration)))
                #expect(gust.angle(at: 0.5, date: start.addingTimeInterval(GustState.duration + 1)) == 0)
            }
        }
    }
    @Test @MainActor func hidingStopsNewEffectsWithoutDeletingAnActiveFlight() {
        let motion = ClotheslineMotion()
        let flight = ButterflyFlight(start: Date(), iconFrame: CGRect(x: 100, y: 600, width: 52, height: 52), screenSize: CGSize(width: 1440, height: 900), edge: .bottom)
        let gust = GustState(start: Date(), fromStart: true)
        motion.butterfly = flight; motion.gust = gust
        motion.stopSchedulingAmbience()
        #expect(motion.butterfly == flight)
        #expect(motion.gust == gust)
        motion.stopAmbience()
        #expect(motion.butterfly == nil && motion.gust.start == .distantPast)
    }
}
