import Foundation
import Testing
@testable import ClothesDock

struct HoverMotionTests {
    @Test @MainActor func crossingAdjacentSlotsDoesNotRepeatedlyRestartWave() {
        let motion = ClotheslineMotion()
        let start = Date(timeIntervalSinceReferenceDate: 100)
        motion.trigger(at: 0.5, date: start)
        for index in 1...10 {
            motion.trigger(at: index.isMultiple(of: 2) ? 0.5 : 0.53, date: start.addingTimeInterval(Double(index) * 0.02))
        }
        #expect(motion.pulse == start)
        #expect(motion.focus == 0.5)
        motion.trigger(at: 0.53, date: start.addingTimeInterval(0.4))
        #expect(motion.pulse == start.addingTimeInterval(0.4))
    }
    @Test @MainActor func clickAndDistantHoverStillRespondImmediately() {
        let motion = ClotheslineMotion()
        let start = Date(timeIntervalSinceReferenceDate: 100)
        motion.trigger(at: 0.2, date: start)
        motion.trigger(at: 0.7, date: start.addingTimeInterval(0.05))
        #expect(motion.focus == 0.7)
        motion.trigger(at: 0.71, launch: true, date: start.addingTimeInterval(0.1))
        #expect(motion.pulse == start.addingTimeInterval(0.1))
        #expect(motion.strength == 1.4)
    }
}
