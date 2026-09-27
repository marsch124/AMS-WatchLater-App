import SwiftUI

// Hand-drawn marks. No symbol sets, no emoji — a line or two each, so they
// read at a glance and match the icon.

private struct StrokeMark<S: Shape>: View {
    let shape: S
    let size: CGFloat
    let weight: CGFloat
    var body: some View {
        shape.stroke(style: StrokeStyle(lineWidth: weight, lineCap: .round, lineJoin: .round))
            .frame(width: size, height: size)
    }
}

struct TickMark: View {
    var size: CGFloat = 18; var weight: CGFloat = 2.4
    var body: some View {
        StrokeMark(shape: Tick(), size: size, weight: weight)
    }
    struct Tick: Shape {
        func path(in r: CGRect) -> Path {
            var p = Path()
            p.move(to: CGPoint(x: r.minX + r.width * 0.15, y: r.midY + r.height * 0.05))
            p.addLine(to: CGPoint(x: r.minX + r.width * 0.42, y: r.maxY - r.height * 0.18))
            p.addLine(to: CGPoint(x: r.maxX - r.width * 0.12, y: r.minY + r.height * 0.22))
            return p
        }
    }
}

struct CrossMark: View {
    var size: CGFloat = 16; var weight: CGFloat = 2.4
    var body: some View { StrokeMark(shape: Cross(), size: size, weight: weight) }
    struct Cross: Shape {
        func path(in r: CGRect) -> Path {
            var p = Path()
            let i = r.insetBy(dx: r.width * 0.2, dy: r.height * 0.2)
            p.move(to: CGPoint(x: i.minX, y: i.minY)); p.addLine(to: CGPoint(x: i.maxX, y: i.maxY))
            p.move(to: CGPoint(x: i.maxX, y: i.minY)); p.addLine(to: CGPoint(x: i.minX, y: i.maxY))
            return p
        }
    }
}

struct PlusMark: View {
    var size: CGFloat = 18; var weight: CGFloat = 2.6
    var body: some View { StrokeMark(shape: Plus(), size: size, weight: weight) }
    struct Plus: Shape {
        func path(in r: CGRect) -> Path {
            var p = Path()
            let i = r.insetBy(dx: r.width * 0.15, dy: r.height * 0.15)
            p.move(to: CGPoint(x: i.midX, y: i.minY)); p.addLine(to: CGPoint(x: i.midX, y: i.maxY))
            p.move(to: CGPoint(x: i.minX, y: i.midY)); p.addLine(to: CGPoint(x: i.maxX, y: i.midY))
            return p
        }
    }
}

/// A play triangle inside a ring — the app's own icon, small.
struct PlayMark: View {
    var size: CGFloat = 18; var weight: CGFloat = 2.2
    var body: some View {
        ZStack {
            Circle().strokeBorder(lineWidth: weight)
            Triangle().fill().frame(width: size * 0.42, height: size * 0.42).offset(x: size * 0.04)
        }
        .frame(width: size, height: size)
    }
    struct Triangle: Shape {
        func path(in r: CGRect) -> Path {
            var p = Path()
            p.move(to: CGPoint(x: r.minX, y: r.minY))
            p.addLine(to: CGPoint(x: r.maxX, y: r.midY))
            p.addLine(to: CGPoint(x: r.minX, y: r.maxY))
            p.closeSubpath()
            return p
        }
    }
}

/// A drawing pin: head, and a needle.
struct PinMark: View {
    var size: CGFloat = 18; var weight: CGFloat = 2.2
    var filled = false
    var body: some View {
        ZStack {
            StrokeMark(shape: Pin(), size: size, weight: weight)
            if filled { Pin.Head().fill().frame(width: size, height: size) }
        }
    }
    struct Pin: Shape {
        func path(in r: CGRect) -> Path {
            var p = Head().path(in: r)
            p.move(to: CGPoint(x: r.midX, y: r.minY + r.height * 0.62))
            p.addLine(to: CGPoint(x: r.midX, y: r.maxY - r.height * 0.05))
            return p
        }
        struct Head: Shape {
            func path(in r: CGRect) -> Path {
                var p = Path()
                p.move(to: CGPoint(x: r.minX + r.width * 0.28, y: r.minY + r.height * 0.1))
                p.addLine(to: CGPoint(x: r.maxX - r.width * 0.28, y: r.minY + r.height * 0.1))
                p.addLine(to: CGPoint(x: r.maxX - r.width * 0.32, y: r.minY + r.height * 0.4))
                p.addLine(to: CGPoint(x: r.maxX - r.width * 0.15, y: r.minY + r.height * 0.62))
                p.addLine(to: CGPoint(x: r.minX + r.width * 0.15, y: r.minY + r.height * 0.62))
                p.addLine(to: CGPoint(x: r.minX + r.width * 0.32, y: r.minY + r.height * 0.4))
                p.closeSubpath()
                return p
            }
        }
    }
}

/// A bin: lid, body, one line down the middle.
struct BinMark: View {
    var size: CGFloat = 18; var weight: CGFloat = 2.2
    var body: some View { StrokeMark(shape: Bin(), size: size, weight: weight) }
    struct Bin: Shape {
        func path(in r: CGRect) -> Path {
            var p = Path()
            let w = r.width, h = r.height
            p.move(to: CGPoint(x: r.minX + w * 0.15, y: r.minY + h * 0.25))
            p.addLine(to: CGPoint(x: r.maxX - w * 0.15, y: r.minY + h * 0.25))
            p.move(to: CGPoint(x: r.minX + w * 0.38, y: r.minY + h * 0.25))
            p.addLine(to: CGPoint(x: r.minX + w * 0.42, y: r.minY + h * 0.12))
            p.addLine(to: CGPoint(x: r.maxX - w * 0.42, y: r.minY + h * 0.12))
            p.addLine(to: CGPoint(x: r.maxX - w * 0.38, y: r.minY + h * 0.25))
            p.move(to: CGPoint(x: r.minX + w * 0.24, y: r.minY + h * 0.25))
            p.addLine(to: CGPoint(x: r.minX + w * 0.3, y: r.maxY - h * 0.1))
            p.addLine(to: CGPoint(x: r.maxX - w * 0.3, y: r.maxY - h * 0.1))
            p.addLine(to: CGPoint(x: r.maxX - w * 0.24, y: r.minY + h * 0.25))
            p.move(to: CGPoint(x: r.midX, y: r.minY + h * 0.4))
            p.addLine(to: CGPoint(x: r.midX, y: r.maxY - h * 0.25))
            return p
        }
    }
}

/// Two heads side by side — watching together.
struct PairMark: View {
    var size: CGFloat = 18; var weight: CGFloat = 2.2
    var filled = false
    var body: some View {
        ZStack {
            if filled { Pair().fill() } else { Pair().stroke(style: StrokeStyle(lineWidth: weight, lineCap: .round)) }
        }
        .frame(width: size, height: size)
    }
    struct Pair: Shape {
        func path(in r: CGRect) -> Path {
            var p = Path()
            let w = r.width, h = r.height
            p.addEllipse(in: CGRect(x: r.minX + w * 0.12, y: r.minY + h * 0.14, width: w * 0.3, height: h * 0.3))
            p.addEllipse(in: CGRect(x: r.minX + w * 0.55, y: r.minY + h * 0.14, width: w * 0.3, height: h * 0.3))
            p.move(to: CGPoint(x: r.minX + w * 0.05, y: r.maxY - h * 0.12))
            p.addQuadCurve(to: CGPoint(x: r.minX + w * 0.5, y: r.maxY - h * 0.12),
                           control: CGPoint(x: r.minX + w * 0.27, y: r.minY + h * 0.45))
            p.move(to: CGPoint(x: r.minX + w * 0.5, y: r.maxY - h * 0.12))
            p.addQuadCurve(to: CGPoint(x: r.maxX - w * 0.05, y: r.maxY - h * 0.12),
                           control: CGPoint(x: r.minX + w * 0.72, y: r.minY + h * 0.45))
            return p
        }
    }
}

/// A magnifying glass.
struct SearchMark: View {
    var size: CGFloat = 16; var weight: CGFloat = 2.2
    var body: some View { StrokeMark(shape: Glass(), size: size, weight: weight) }
    struct Glass: Shape {
        func path(in r: CGRect) -> Path {
            var p = Path()
            p.addEllipse(in: CGRect(x: r.minX + r.width * 0.1, y: r.minY + r.height * 0.1,
                                    width: r.width * 0.58, height: r.height * 0.58))
            p.move(to: CGPoint(x: r.minX + r.width * 0.62, y: r.minY + r.height * 0.62))
            p.addLine(to: CGPoint(x: r.maxX - r.width * 0.08, y: r.maxY - r.height * 0.08))
            return p
        }
    }
}

/// A pencil, for the note.
struct PencilMark: View {
    var size: CGFloat = 15; var weight: CGFloat = 2
    var body: some View { StrokeMark(shape: Pencil(), size: size, weight: weight) }
    struct Pencil: Shape {
        func path(in r: CGRect) -> Path {
            var p = Path()
            p.move(to: CGPoint(x: r.minX + r.width * 0.15, y: r.maxY - r.height * 0.15))
            p.addLine(to: CGPoint(x: r.minX + r.width * 0.2, y: r.maxY - r.height * 0.4))
            p.addLine(to: CGPoint(x: r.maxX - r.width * 0.25, y: r.minY + r.height * 0.15))
            p.addLine(to: CGPoint(x: r.maxX - r.width * 0.1, y: r.minY + r.height * 0.3))
            p.addLine(to: CGPoint(x: r.minX + r.width * 0.4, y: r.maxY - r.height * 0.2))
            p.closeSubpath()
            return p
        }
    }
}

/// A clock face — plan an evening.
struct ClockMark: View {
    var size: CGFloat = 18; var weight: CGFloat = 2.2
    var body: some View { StrokeMark(shape: Face(), size: size, weight: weight) }
    struct Face: Shape {
        func path(in r: CGRect) -> Path {
            var p = Path()
            p.addEllipse(in: r.insetBy(dx: r.width * 0.08, dy: r.height * 0.08))
            p.move(to: CGPoint(x: r.midX, y: r.minY + r.height * 0.28))
            p.addLine(to: CGPoint(x: r.midX, y: r.midY))
            p.addLine(to: CGPoint(x: r.midX + r.width * 0.22, y: r.midY + r.height * 0.14))
            return p
        }
    }
}

/// A little tag — for the tags.
struct TagMark: View {
    var size: CGFloat = 15; var weight: CGFloat = 2
    var body: some View { StrokeMark(shape: Tag(), size: size, weight: weight) }
    struct Tag: Shape {
        func path(in r: CGRect) -> Path {
            var p = Path()
            p.move(to: CGPoint(x: r.minX + r.width * 0.1, y: r.minY + r.height * 0.1))
            p.addLine(to: CGPoint(x: r.midX, y: r.minY + r.height * 0.1))
            p.addLine(to: CGPoint(x: r.maxX - r.width * 0.1, y: r.midY))
            p.addLine(to: CGPoint(x: r.midX, y: r.maxY - r.height * 0.1))
            p.addLine(to: CGPoint(x: r.minX + r.width * 0.1, y: r.midY))
            p.closeSubpath()
            p.addEllipse(in: CGRect(x: r.minX + r.width * 0.26, y: r.minY + r.height * 0.26,
                                    width: r.width * 0.12, height: r.height * 0.12))
            return p
        }
    }
}
