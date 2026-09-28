import SwiftUI

/// Hand-drawn icons written as SVG path data in a 24×24 box — the same pen as
/// AMS Instructions (its Settings sliders are copied stroke for stroke), so the
/// family of apps looks drawn by one hand. The tab icons are exactly the ones
/// in the layout he picked on 2026-09-28.
enum GlyphArt {
    static let watch = ["M12.2 3.3c4.9-.1 8.6 3.9 8.5 8.8-.1 4.8-3.9 8.7-8.8 8.6-4.9-.1-8.6-3.9-8.5-8.9.1-4.8 4-8.4 8.8-8.5Z",
                        "M10 8.6c-.1 2.3-.1 4.6 0 6.9 1.9-1.1 3.8-2.2 5.6-3.5-1.8-1.2-3.7-2.3-5.6-3.4Z"]
    static let library = ["M4.4 4.3c-.2 5.2-.1 10.4.1 15.6h3c.2-5.2.1-10.4-.1-15.6-1-.1-2-.1-3 0Z",
                          "M9.3 6.2c-.2 4.6-.1 9.1.1 13.7h3c.2-4.6.2-9.1 0-13.7h-3.1Z",
                          "M14.3 5.6c1-.3 2-.5 3-.6 1.3 4.8 2.4 9.6 3.4 14.4-1 .3-2 .5-3 .6-1.2-4.8-2.3-9.6-3.4-14.4Z"]
    static let topics = ["M6.4 4.4c1.3 0 2.3 1 2.3 2.3 0 1.3-1.1 2.3-2.3 2.3-1.3 0-2.3-1-2.3-2.3 0-1.4 1-2.3 2.3-2.3Z",
                         "M17.6 6.1c1.3 0 2.3 1 2.3 2.3s-1 2.3-2.3 2.3-2.3-1-2.3-2.3 1-2.3 2.3-2.3Z",
                         "M10.2 15.1c1.3 0 2.3 1 2.3 2.3 0 1.3-1 2.3-2.3 2.3-1.4 0-2.4-1-2.3-2.3 0-1.3 1-2.3 2.3-2.3Z",
                         "M8.6 7.2c2.2.2 4.4.5 6.7.9M7.3 8.9c.9 2 1.7 4 2.4 6.1M16.3 10.4c-1.4 1.6-2.8 3.3-4.4 4.9"]
    static let find = ["M10.4 3.9c3.7-.1 6.5 2.8 6.5 6.4 0 3.6-2.9 6.5-6.5 6.4-3.6 0-6.4-2.9-6.4-6.5.1-3.5 2.9-6.3 6.4-6.3Z",
                       "M15.2 15.1c1.8 1.7 3.4 3.4 5 5.3"]
    static let settings = ["M4.2 7.3c.9-.1 1.8-.2 2.7-.2M11.5 7.1c2.8-.1 5.5 0 8.3.2",
                           "M7.05 7.2C7 6 7.95 5.05 9.2 5.05c1.3 0 2.15.95 2.15 2.15 0 1.3-.95 2.2-2.15 2.15C7.9 9.3 7.05 8.4 7.05 7.2Z",
                           "M4.2 12.1c2.7-.2 5.4-.2 8.5-.2M17.3 11.9c.9 0 1.8.1 2.7.2",
                           "M12.85 12c-.05-1.25.9-2.15 2.15-2.15 1.3 0 2.15.95 2.15 2.15 0 1.3-.95 2.2-2.15 2.15-1.3-.05-2.15-.95-2.15-2.15Z",
                           "M4.2 16.9c.5-.1 1-.1 1.5-.1M10.5 16.7c3.1-.1 6.2 0 9.3.2",
                           "M6.05 16.8C6 15.55 6.95 14.65 8.2 14.65c1.3 0 2.15.95 2.15 2.15 0 1.3-.95 2.2-2.15 2.15-1.3-.05-2.15-.95-2.15-2.15Z"]
    static let cloud = ["M7.2 18.3c-2.3.1-3.9-1.5-3.8-3.5.1-1.9 1.6-3.3 3.5-3.3.3-2.8 2.5-4.9 5.3-4.8 2.4.1 4.3 1.7 4.9 3.9 2.2-.1 3.9 1.7 3.8 3.9-.1 2.1-1.8 3.7-3.9 3.7-3.3.2-6.5.2-9.8.1Z"]
    static let importIn = ["M12.1 3.8c-.1 4.5-.1 8.9.1 13.3M7.6 12.8c1.5 1.5 3 3 4.6 4.4 1.4-1.5 2.9-3 4.5-4.5",
                           "M4.6 20.2c5 .2 9.9.2 14.9-.1"]
    static let exportOut = ["M12 17c.1-4.4.1-8.8-.1-13.3M7.5 8.2c1.5-1.5 3-3 4.6-4.4 1.4 1.5 2.9 3 4.5 4.5",
                            "M4.6 20.2c5 .2 9.9.2 14.9-.1"]
    static let book = ["M12 6.4C9.7 5 7 4.6 4.3 5c-.2 4.7-.1 9.4.1 14 2.6-.4 5.2 0 7.6 1.4 2.4-1.3 5-1.8 7.7-1.4.2-4.6.2-9.3 0-14-2.7-.4-5.4 0-7.7 1.4Z",
                       "M12 6.4c-.1 4.7-.1 9.3 0 14"]
    static let sprout = ["M12.1 20.6c-.2-3.5-.1-6.9.2-10.3", "M12.3 12.1C9.6 12.5 6.4 11.4 5 8.1c3-.8 6.3.2 7.3 4Z",
                         "M12.2 9.9c.2-3 2.3-5.6 6.3-5.7.2 3.7-2.5 6.1-6.3 5.7Z", "M8 20.6c2.7-.2 5.3-.2 8 .1"]
    static let pair = ["M7.8 4.8c1.6 0 2.8 1.3 2.8 2.8 0 1.6-1.3 2.8-2.9 2.8-1.5 0-2.8-1.3-2.7-2.9 0-1.5 1.3-2.7 2.8-2.7Z",
                       "M16.4 4.8c1.6 0 2.8 1.2 2.8 2.8 0 1.5-1.3 2.8-2.9 2.8-1.5-.1-2.7-1.3-2.7-2.9.1-1.5 1.3-2.7 2.8-2.7Z",
                       "M3.1 19.3c.4-3.4 2.2-5.8 4.7-5.8 2.3 0 4.1 2.2 4.4 5.8M12.2 19.3c.4-3.4 2.1-5.8 4.3-5.8 2.4 0 4.1 2.3 4.5 5.8"]
}

/// Draws a GlyphArt in the current foreground style, at any size, with the
/// same line weight the SVGs use (1.9 in 24).
struct Glyph: View {
    let art: [String]
    var size: CGFloat = 24
    var weight: CGFloat = 1.9

    var body: some View {
        SVGShape(paths: art)
            .stroke(style: StrokeStyle(lineWidth: weight * size / 24, lineCap: .round, lineJoin: .round))
            .frame(width: size, height: size)
    }
}

/// A tiny reader for SVG path data — M L H V C S Q Z, absolute and relative,
/// with numbers run together the way SVG writes them ("2.3-.1", ".5.9").
struct SVGShape: Shape {
    let paths: [String]

    func path(in rect: CGRect) -> Path {
        let scale = min(rect.width, rect.height) / 24
        var p = Path()
        for d in paths { SVGShape.append(d, to: &p) }
        return p.applying(CGAffineTransform(scaleX: scale, y: scale)
            .translatedBy(x: rect.minX / scale, y: rect.minY / scale))
    }

    static func tokens(_ d: String) -> [String] {
        var out: [String] = []
        var num = ""
        func flush() { if !num.isEmpty { out.append(num); num = "" } }
        for ch in d {
            if ch.isLetter && ch != "e" {
                flush(); out.append(String(ch))
            } else if ch == "-" {
                if num.last == "e" { num.append(ch) } else { flush(); num = "-" }
            } else if ch == "." {
                if num.contains(".") && !num.contains("e") { flush() }
                num.append(ch)
            } else if ch.isNumber || ch == "e" {
                num.append(ch)
            } else {
                flush()
            }
        }
        flush()
        return out
    }

    static func append(_ d: String, to p: inout Path) {
        let t = tokens(d)
        var i = 0
        var cmd: Character = "M"
        var cur = CGPoint.zero, start = CGPoint.zero, lastCtrl: CGPoint? = nil
        func n() -> CGFloat { defer { i += 1 }; return CGFloat(Double(t[i]) ?? 0) }
        func hasNumber() -> Bool { i < t.count && Double(t[i]) != nil }
        while i < t.count {
            if let c = t[i].first, t[i].count == 1, c.isLetter { cmd = c; i += 1 }
            let rel = cmd.isLowercase
            let o = rel ? cur : .zero
            switch cmd.uppercased() {
            case "M":
                cur = CGPoint(x: o.x + n(), y: o.y + n()); start = cur; p.move(to: cur); lastCtrl = nil
                cmd = rel ? "l" : "L"   // further pairs are lines
            case "L":
                cur = CGPoint(x: o.x + n(), y: o.y + n()); p.addLine(to: cur); lastCtrl = nil
            case "H":
                cur = CGPoint(x: (rel ? cur.x : 0) + n(), y: cur.y); p.addLine(to: cur); lastCtrl = nil
            case "V":
                cur = CGPoint(x: cur.x, y: (rel ? cur.y : 0) + n()); p.addLine(to: cur); lastCtrl = nil
            case "C":
                let c1 = CGPoint(x: o.x + n(), y: o.y + n()), c2 = CGPoint(x: o.x + n(), y: o.y + n())
                cur = CGPoint(x: o.x + n(), y: o.y + n())
                p.addCurve(to: cur, control1: c1, control2: c2); lastCtrl = c2
            case "S":
                let c1 = lastCtrl.map { CGPoint(x: 2 * cur.x - $0.x, y: 2 * cur.y - $0.y) } ?? cur
                let c2 = CGPoint(x: o.x + n(), y: o.y + n())
                cur = CGPoint(x: o.x + n(), y: o.y + n())
                p.addCurve(to: cur, control1: c1, control2: c2); lastCtrl = c2
            case "Q":
                let c = CGPoint(x: o.x + n(), y: o.y + n())
                cur = CGPoint(x: o.x + n(), y: o.y + n())
                p.addQuadCurve(to: cur, control: c); lastCtrl = nil
            case "Z":
                p.closeSubpath(); cur = start; lastCtrl = nil
            default:
                i += 1
            }
            if cmd.uppercased() == "Z" { cmd = "M" }
            // A command letter may be followed by several sets of numbers.
            if !hasNumber(), i < t.count, !(t[i].first?.isLetter ?? false) { i += 1 }
        }
    }
}
