import SwiftUI

/// All effect geometry uses SwiftUI's top-left origin, relative to one physical screen.
enum AmbienceLayout {
    static func iconOnScreen(_ icon: CGRect, dock: CGRect, screen: CGRect) -> CGRect {
        icon.offsetBy(dx: dock.minX - screen.minX, dy: screen.maxY - dock.maxY)
    }
    static func outsidePoint(size: CGSize, edge: Edge, fromStart: Bool, cross: Double, margin: Double) -> CGPoint {
        let along = fromStart ? -margin : (edge.isVertical ? size.height : size.width) + margin
        return edge.isVertical ? CGPoint(x: cross, y: along) : CGPoint(x: along, y: cross)
    }
}

struct GustState: Equatable {
    var start = Date.distantPast
    var fromStart = true
    static let duration: TimeInterval = 4.2
    static let margin: Double = 240
    func progress(at date: Date) -> Double { min(1, max(0, date.timeIntervalSince(start) / Self.duration)) }
    func isActive(at date: Date) -> Bool {
        let age = date.timeIntervalSince(start)
        return age >= 0 && age < Self.duration
    }
    func center(size: CGSize, edge: Edge, cross: Double, date: Date) -> CGPoint {
        let a = AmbienceLayout.outsidePoint(size: size, edge: edge, fromStart: fromStart, cross: cross, margin: Self.margin)
        let b = AmbienceLayout.outsidePoint(size: size, edge: edge, fromStart: !fromStart, cross: cross, margin: Self.margin)
        let k = progress(at: date)
        return CGPoint(x: a.x + (b.x - a.x) * k, y: a.y + (b.y - a.y) * k)
    }
    private func front(_ date: Date) -> Double {
        let k = progress(at: date) * 1.3 - 0.15
        return fromStart ? k : 1 - k
    }
    func displacement(at position: Double, date: Date) -> Double {
        guard isActive(at: date) else { return 0 }
        let t = date.timeIntervalSince(start), d = position - front(date)
        return 16 * sin(.pi * progress(at: date)) * exp(-pow(d / 0.22, 2)) * sin(t * 9)
    }
    func angle(at position: Double, date: Date) -> Double {
        guard isActive(at: date) else { return 0 }
        let t = date.timeIntervalSince(start), d = position - front(date)
        return 30 * sin(.pi * progress(at: date)) * exp(-pow(d / 0.22, 2)) * sin(t * 7 + position * 2)
    }
}

/// Enter beyond a screen edge, land on an icon, then leave beyond the opposite edge.
struct ButterflyFlight: Equatable {
    let start: Date
    let target: CGPoint
    let enter: CGPoint
    let exit: CGPoint
    let controlIn: CGPoint
    let controlOut: CGPoint
    let inDuration: TimeInterval
    let outDuration: TimeInterval
    var restDuration: TimeInterval { 2.4 }
    var duration: TimeInterval { inDuration + restDuration + outDuration }

    init(start: Date, iconFrame: CGRect, screenSize: CGSize, edge: Edge, fromStart: Bool = Bool.random()) {
        self.start = start
        target = CGPoint(x: iconFrame.midX, y: iconFrame.minY + 3)
        let cross = edge.isVertical ? target.x : target.y
        let inward: Double = (edge == .top || edge == .left) ? 1 : -1
        let dimension = edge.isVertical ? screenSize.width : screenSize.height
        let flightCross = min(max(45, cross + inward * 100), max(45, dimension - 45))
        enter = AmbienceLayout.outsidePoint(size: screenSize, edge: edge, fromStart: fromStart, cross: flightCross, margin: 90)
        exit = AmbienceLayout.outsidePoint(size: screenSize, edge: edge, fromStart: !fromStart, cross: flightCross, margin: 90)
        if edge.isVertical {
            controlIn = CGPoint(x: flightCross + inward * 70, y: (enter.y + target.y) / 2)
            controlOut = CGPoint(x: flightCross + inward * 90, y: (target.y + exit.y) / 2)
        } else {
            controlIn = CGPoint(x: (enter.x + target.x) / 2, y: flightCross + inward * 70)
            controlOut = CGPoint(x: (target.x + exit.x) / 2, y: flightCross + inward * 90)
        }
        inDuration = max(1.8, hypot(enter.x - target.x, enter.y - target.y) / 420)
        outDuration = max(1.8, hypot(exit.x - target.x, exit.y - target.y) / 420)
    }
    func position(at t: TimeInterval) -> CGPoint {
        func smooth(_ k: Double) -> Double { let c = min(1, max(0, k)); return c * c * (3 - 2 * c) }
        func quad(_ a: CGPoint, _ c: CGPoint, _ b: CGPoint, _ k: Double) -> CGPoint {
            let u = 1 - k
            let flutter = sin(.pi * k) * sin(t * 7) * 3
            return CGPoint(x: u * u * a.x + 2 * u * k * c.x + k * k * b.x,
                           y: u * u * a.y + 2 * u * k * c.y + k * k * b.y + flutter)
        }
        if t < 0 { return enter }
        if t < inDuration {
            let k = min(1, max(0, t / inDuration))
            // Enter the visible screen quickly, then slow down gently for landing.
            return quad(enter, controlIn, target, 1 - pow(1 - k, 2))
        }
        if t < inDuration + restDuration {
            let rest = t - inDuration, envelope = sin(.pi * rest / restDuration)
            return CGPoint(x: target.x + sin(rest * 2.2) * envelope, y: target.y + sin(rest * 3) * envelope)
        }
        return quad(target, controlOut, exit, smooth((t - inDuration - restDuration) / outDuration))
    }
    func wingAngle(at t: TimeInterval) -> Double {
        let flying = t < inDuration || t >= inDuration + restDuration
        return 18 + sin(t * (flying ? 27 : 5.5)) * (flying ? 54 : 18)
    }
}

struct ButterflyWing: Shape {
    func path(in r: CGRect) -> Path {
        func p(_ x: Double, _ y: Double) -> CGPoint { CGPoint(x: r.minX + x * r.width, y: r.minY + y * r.height) }
        var path = Path()
        path.move(to: p(1, 0.48))
        path.addCurve(to: p(0.10, 0.03), control1: p(0.78, 0.12), control2: p(0.12, -0.06))
        path.addCurve(to: p(0.06, 0.43), control1: p(-0.08, 0.10), control2: p(-0.02, 0.34))
        path.addCurve(to: p(0.32, 0.56), control1: p(0.08, 0.52), control2: p(0.18, 0.55))
        path.addCurve(to: p(0.18, 0.85), control1: p(0.02, 0.62), control2: p(0.06, 0.78))
        path.addCurve(to: p(0.72, 0.93), control1: p(0.27, 1.04), control2: p(0.63, 1.05))
        path.addCurve(to: p(1, 0.48), control1: p(0.87, 0.78), control2: p(0.91, 0.61))
        path.closeSubpath()
        return path
    }
}

/// A blue morpho silhouette with scalloped hindwings, veins, spotted edges and antennae.
struct ButterflySprite: View {
    let wingAngle: Double
    private var wing: some View {
        ButterflyWing()
            .fill(LinearGradient(colors: [Color(red: 0.13, green: 0.22, blue: 0.50), .cyan, Color(red: 0.15, green: 0.38, blue: 0.88), Color(red: 0.27, green: 0.18, blue: 0.48)], startPoint: .topLeading, endPoint: .bottomTrailing))
            .overlay(ButterflyWing().stroke(Color(red: 0.08, green: 0.15, blue: 0.30), lineWidth: 1.4))
            .overlay {
                Canvas { context, size in
                    let root = CGPoint(x: size.width, y: size.height * 0.49)
                    for tip in [CGPoint(x: 0.2, y: 0.08), CGPoint(x: 0.08, y: 0.32), CGPoint(x: 0.3, y: 0.54), CGPoint(x: 0.20, y: 0.76), CGPoint(x: 0.52, y: 0.92)] {
                        var vein = Path(); vein.move(to: root)
                        vein.addQuadCurve(to: CGPoint(x: size.width * tip.x, y: size.height * tip.y), control: CGPoint(x: size.width * 0.57, y: size.height * tip.y))
                        context.stroke(vein, with: .color(.indigo.opacity(0.55)), lineWidth: 0.65)
                    }
                    for dot in [CGPoint(x: 0.19, y: 0.14), CGPoint(x: 0.13, y: 0.27), CGPoint(x: 0.18, y: 0.40), CGPoint(x: 0.25, y: 0.77), CGPoint(x: 0.44, y: 0.89), CGPoint(x: 0.63, y: 0.86)] {
                        let rect = CGRect(x: size.width * dot.x - 1.2, y: size.height * dot.y - 1.2, width: 2.4, height: 2.4)
                        context.fill(Path(ellipseIn: rect), with: .color(Color(red: 1, green: 0.94, blue: 0.72)))
                    }
                }
            }
            .frame(width: 24, height: 43)
    }
    var body: some View {
        ZStack {
            wing.rotation3DEffect(.degrees(wingAngle), axis: (x: 0, y: 1, z: 0), anchor: .trailing, perspective: 0.25).offset(x: -13)
            wing.scaleEffect(x: -1, y: 1).rotation3DEffect(.degrees(-wingAngle), axis: (x: 0, y: 1, z: 0), anchor: .leading, perspective: 0.25).offset(x: 13)
            Capsule().fill(Color(red: 0.12, green: 0.15, blue: 0.20)).frame(width: 3.5, height: 22).offset(y: 3)
            Circle().fill(Color(red: 0.16, green: 0.19, blue: 0.24)).frame(width: 5, height: 5).offset(y: -10)
            Path { p in
                p.move(to: CGPoint(x: 31, y: 19)); p.addQuadCurve(to: CGPoint(x: 26, y: 10), control: CGPoint(x: 26, y: 14))
                p.move(to: CGPoint(x: 33, y: 19)); p.addQuadCurve(to: CGPoint(x: 38, y: 10), control: CGPoint(x: 38, y: 14))
            }.stroke(Color(white: 0.15), style: StrokeStyle(lineWidth: 0.9, lineCap: .round))
        }
        .frame(width: 64, height: 60)
        .shadow(color: .black.opacity(0.18), radius: 2, y: 2)
    }
}

struct WindSprite: View {
    let age: TimeInterval
    @Environment(\.colorScheme) private var scheme
    var body: some View {
        Canvas { context, size in
            let ink: Color = scheme == .dark ? Color(red: 0.68, green: 0.89, blue: 1) : Color(red: 0.28, green: 0.55, blue: 0.66)
            for i in 0..<5 {
                let row = 25 + Double(i) * 18 + sin(age * 4 + Double(i)) * 5
                let end = 235 + Double(i % 3) * 19
                var streak = Path()
                streak.move(to: CGPoint(x: 12 + Double(i) * 9, y: row))
                streak.addCurve(to: CGPoint(x: end, y: row), control1: CGPoint(x: 90, y: row - 10), control2: CGPoint(x: 175, y: row + 10))
                streak.addCurve(to: CGPoint(x: end - 13, y: row - 13), control1: CGPoint(x: end + 31, y: row), control2: CGPoint(x: end + 23, y: row - 32))
                context.stroke(streak, with: .linearGradient(Gradient(colors: [ink.opacity(0.04), ink.opacity(0.80), ink.opacity(0.40)]), startPoint: CGPoint(x: 12, y: row), endPoint: CGPoint(x: 300, y: row)), style: StrokeStyle(lineWidth: i % 2 == 0 ? 2 : 1.2, lineCap: .round))
            }
            for i in 0..<3 {
                var leafContext = context
                let x = 85 + Double(i) * 67 + sin(age * 3 + Double(i)) * 12
                let y = 24 + Double(i) * 35 + cos(age * 4 + Double(i)) * 12
                leafContext.translateBy(x: x, y: y)
                leafContext.rotate(by: .degrees(age * (i == 1 ? -85 : 110) + Double(i) * 60))
                var leaf = Path(); leaf.move(to: CGPoint(x: -9, y: 0))
                leaf.addQuadCurve(to: CGPoint(x: 9, y: 0), control: CGPoint(x: 2, y: -11))
                leaf.addQuadCurve(to: CGPoint(x: -9, y: 0), control: CGPoint(x: -2, y: 11))
                leafContext.fill(leaf, with: .color(i == 1 ? Color(red: 0.75, green: 0.58, blue: 0.26) : Color(red: 0.42, green: 0.61, blue: 0.39)))
                var vein = Path(); vein.move(to: CGPoint(x: -8, y: 0)); vein.addLine(to: CGPoint(x: 9, y: 0))
                leafContext.stroke(vein, with: .color(.white.opacity(0.5)), lineWidth: 0.6)
            }
        }.frame(width: 320, height: 140)
    }
}

struct AmbienceView: View {
    @ObservedObject var motion: ClotheslineMotion
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        ZStack(alignment: .topLeading) {
            if !reduceMotion {
                if let flight = motion.butterfly {
                    TimelineView(.animation(minimumInterval: 1.0 / 30)) { timeline in
                        let t = timeline.date.timeIntervalSince(flight.start)
                        ButterflySprite(wingAngle: flight.wingAngle(at: t))
                            .rotationEffect(.degrees(sin(t * 3) * 9))
                            .position(flight.position(at: t))
                    }
                    .task(id: flight.start) {
                        do { try await Task.sleep(nanoseconds: UInt64((flight.duration + 0.1) * 1_000_000_000)) } catch { return }
                        if motion.butterfly?.start == flight.start { motion.butterfly = nil }
                    }
                }
                if motion.gust.start != .distantPast {
                    TimelineView(.animation(minimumInterval: 1.0 / 30)) { timeline in
                        let screen = motion.ambienceFrame
                        let icon = motion.iconFrames.first.map { AmbienceLayout.iconOnScreen($0, dock: motion.dockFrame, screen: screen) }
                        let cross = motion.edge.isVertical ? (icon?.midX ?? screen.width / 2) : (icon?.midY ?? screen.height / 2)
                        WindSprite(age: timeline.date.timeIntervalSince(motion.gust.start))
                            .scaleEffect(x: motion.gust.fromStart ? 1 : -1, y: 1)
                            .rotationEffect(.degrees(motion.edge.isVertical ? 90 : 0))
                            .position(motion.gust.center(size: screen.size, edge: motion.edge, cross: cross, date: timeline.date))
                    }
                    .task(id: motion.gust.start) {
                        let start = motion.gust.start
                        do { try await Task.sleep(nanoseconds: UInt64((GustState.duration + 0.1) * 1_000_000_000)) } catch { return }
                        if motion.gust.start == start { motion.gust = GustState() }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .allowsHitTesting(false).accessibilityHidden(true)
    }
}
