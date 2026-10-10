import AppKit
import SwiftUI

extension Edge {
    var isVertical: Bool { self == .left || self == .right }
}

/// Screen coordinates remain in AppKit's bottom-left coordinate system.
enum ClotheslineLayout {
    static func visibilityFrame(_ frame: CGRect, edge: Edge, visible: Bool, reduceMotion: Bool) -> CGRect {
        guard !visible && !reduceMotion else { return frame }
        switch edge {
        case .bottom: return frame.offsetBy(dx: 0, dy: -18)
        case .top: return frame.offsetBy(dx: 0, dy: 18)
        case .left: return frame.offsetBy(dx: -18, dy: 0)
        case .right: return frame.offsetBy(dx: 18, dy: 0)
        }
    }
    static func dockFrame(screen: CGRect, menuBarTop: CGFloat, edge: Edge, iconSize: CGFloat, offset: CGFloat, length: CGFloat) -> CGRect {
        let thickness = iconSize + 112
        if !edge.isVertical {
            let width = min(length, screen.width - 24)
            let y = edge == .top ? menuBarTop - thickness - offset : screen.minY + offset
            return CGRect(x: screen.midX - width / 2, y: y, width: width, height: thickness)
        }
        let height = min(length, menuBarTop - screen.minY - 24)
        let x = edge == .left ? screen.minX + offset : screen.maxX - thickness - offset
        return CGRect(x: x, y: (menuBarTop + screen.minY - height) / 2, width: thickness, height: height)
    }
    static func ropeFrame(screen: CGRect, menuBarTop: CGFloat, dock: CGRect, edge: Edge) -> CGRect {
        if edge.isVertical { return CGRect(x: dock.minX, y: screen.minY, width: dock.width, height: menuBarTop - screen.minY) }
        return CGRect(x: screen.minX, y: dock.minY, width: screen.width, height: dock.height)
    }
    static func iconHoverRect(slot: CGSize, iconSize: CGFloat, position: Double, edge: Edge) -> CGRect {
        let cross = 14 + sag(at: position)
        if edge.isVertical {
            let x = edge == .right ? slot.width - cross - 4 - iconSize : cross + 4
            return CGRect(x: x, y: (slot.height - iconSize) / 2, width: iconSize, height: iconSize)
        }
        return CGRect(x: (slot.width - iconSize) / 2, y: cross + 4, width: iconSize, height: iconSize)
    }
    static func nearEdge(mouse: CGPoint, screen: CGRect, edge: Edge, distance: Double) -> Bool {
        guard mouse.x >= screen.minX, mouse.x <= screen.maxX, mouse.y >= screen.minY, mouse.y <= screen.maxY else { return false }
        let threshold = max(0, distance)
        switch edge {
        case .bottom: return mouse.y - screen.minY <= threshold
        case .top: return screen.maxY - mouse.y <= threshold
        case .left: return mouse.x - screen.minX <= threshold
        case .right: return screen.maxX - mouse.x <= threshold
        }
    }
    static func sag(at position: Double) -> Double {
        let t = min(1, max(0, position))
        return 42 * 4 * t * (1 - t)
    }
}

@MainActor final class ClotheslineMotion: ObservableObject {
    @Published private(set) var pulse = Date.distantPast
    @Published var isVisible = true
    private(set) var focus = 0.5
    private(set) var strength = 1.0
    @Published var dockFrame = CGRect.zero
    @Published var ropeFrame = CGRect.zero
    var edge: Edge = .bottom
    func position(local coordinate: Double) -> Double {
        let value: Double
        if edge.isVertical { value = (ropeFrame.maxY - dockFrame.maxY + coordinate) / max(1, ropeFrame.height) }
        else { value = (dockFrame.minX - ropeFrame.minX + coordinate) / max(1, ropeFrame.width) }
        return min(1, max(0, value))
    }
    func trigger(at position: Double, launch: Bool = false, date: Date = Date()) {
        // Crossing neighboring slots rapidly should continue the wave, rather than reset its phase.
        if !launch && date.timeIntervalSince(pulse) < 0.35 && abs(position - focus) < 0.15 { return }
        focus = position; strength = launch ? 1.4 : 1; pulse = date
    }
    func displacement(at position: Double, date: Date, enabled: Bool) -> Double {
        guard enabled else { return ClotheslineLayout.sag(at: position) }
        let t = date.timeIntervalSinceReferenceDate
        let age = date.timeIntervalSince(pulse)
        let envelope = sin(.pi * min(1, max(0, position)))
        let breeze = 2.8 * sin(t * 1.5 + position * 5)
        let ripple = age >= 0 && age < 6 ? 12 * strength * exp(-age * 1.25) * sin(age * 11 - abs(position - focus) * 12) : 0
        return ClotheslineLayout.sag(at: position) + envelope * (breeze + ripple)
    }
    func angle(at position: Double, date: Date, enabled: Bool) -> Double {
        guard enabled else { return 0 }
        let t = date.timeIntervalSinceReferenceDate
        let age = date.timeIntervalSince(pulse)
        let breeze = 4.5 * sin(t * 1.8 + position * 9)
        let pendulum = age >= 0 && age < 6 ? 24 * strength * exp(-age * 1.2) * sin(age * 10) * exp(-abs(position - focus) * 9) : 0
        return breeze + pendulum
    }
}

struct ClotheslineShape: Shape {
    let vertical: Bool
    let right: Bool
    let displacements: [Double]
    func path(in rect: CGRect) -> Path {
        var path = Path()
        for step in 0...80 {
            let t = Double(step) / 80
            let cross = 14 + displacements[step]
            let point = vertical ? CGPoint(x: right ? rect.width - cross : cross, y: rect.height * t) : CGPoint(x: rect.width * t, y: cross)
            if step == 0 { path.move(to: point) } else { path.addLine(to: point) }
        }
        return path
    }
}

struct ClotheslineView: View {
    @ObservedObject var model: DockModel
    @ObservedObject var motion: ClotheslineMotion
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var enabled: Bool { model.config.magnify && !reduceMotion && motion.isVisible }
    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: !enabled)) { timeline in
            ClotheslineShape(vertical: model.config.edge.isVertical, right: model.config.edge == .right,
                             displacements: (0...80).map { motion.displacement(at: Double($0) / 80, date: timeline.date, enabled: enabled) })
            .stroke(model.config.ropeColor.color, style: StrokeStyle(lineWidth: model.config.ropeWidth, lineCap: .round, lineJoin: .round))
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}


extension RopeColor {
    var color: Color {
        switch self { case .black: return .black; case .white: return .white; case .gray: return Color(white: 0.5); case .brown: return Color(red: 0.48, green: 0.31, blue: 0.18) }
    }
    var label: String {
        switch self { case .black: return "黑色"; case .white: return "白色"; case .gray: return "灰色"; case .brown: return "棕色" }
    }
}
