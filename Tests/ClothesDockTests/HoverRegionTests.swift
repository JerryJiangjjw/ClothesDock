import Foundation
import Testing
@testable import ClothesDock

struct HoverRegionTests {
    @Test func horizontalHoverExcludesSlotBlankSpaceAndNeighborGaps() {
        for edge in [Edge.top, .bottom] {
            let rect = ClotheslineLayout.iconHoverRect(slot: CGSize(width: 60, height: 164), iconSize: 52, position: 0.5, edge: edge)
            #expect(rect.size == CGSize(width: 52, height: 52))
            #expect(rect.contains(CGPoint(x: 30, y: rect.midY)))
            #expect(!rect.contains(CGPoint(x: 30, y: 5)))
            #expect(!rect.contains(CGPoint(x: 30, y: 150)))
            #expect(!rect.contains(CGPoint(x: 2, y: rect.midY)))
            #expect(!rect.contains(CGPoint(x: 59, y: rect.midY)))
        }
    }
    @Test func sideHoverOnlyCoversIconAndMirrorsCorrectly() {
        let size = CGSize(width: 164, height: 60)
        let left = ClotheslineLayout.iconHoverRect(slot: size, iconSize: 52, position: 0.5, edge: .left)
        let right = ClotheslineLayout.iconHoverRect(slot: size, iconSize: 52, position: 0.5, edge: .right)
        #expect(left.size == CGSize(width: 52, height: 52))
        #expect(right.minX == size.width - left.maxX)
        #expect(!left.contains(CGPoint(x: 5, y: 30)))
        #expect(!left.contains(CGPoint(x: 150, y: 30)))
        #expect(!left.contains(CGPoint(x: left.midX, y: 2)))
    }
}
