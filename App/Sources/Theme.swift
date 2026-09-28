import SwiftUI
#if os(macOS)
import AppKit
#else
import UIKit
#endif

// MARK: - A colour per tab
//
// His ask (2026-09-28): "each tab has a color scheme with headings and all UI
// items following that, so that you always know where you are". The recipe is
// AMS Instructions': one accent per tab, and everything that used to be "the
// green" now means "the colour of the tab you are on". A page opened from a tab
// keeps that tab's colour, so the colour is also the way back.

struct TabTheme: Equatable {
    let accent: Color     // buttons, markers, chips, the tab bar line
    let soft: Color       // a pill that is on, a chip's background, the wash
    let ink: Color        // headings and text written ON the soft colour

    static let watch    = TabTheme(accent: .dyn(0x1d7a5f, 0x5cc0a0), soft: .dyn(0xe2efe9, 0x22332d), ink: .dyn(0x12523f, 0x8ad9bd))
    static let library  = TabTheme(accent: .dyn(0x9a6b12, 0xd8ad5c), soft: .dyn(0xf7edd8, 0x332d1f), ink: .dyn(0x6e4b08, 0xe8c47f))
    static let topics   = TabTheme(accent: .dyn(0x8a5a8f, 0xc79bcd), soft: .dyn(0xf1e6f3, 0x332738), ink: .dyn(0x623d66, 0xdcb8e0))
    static let find     = TabTheme(accent: .dyn(0x1f6f99, 0x6cb6e0), soft: .dyn(0xe1eef6, 0x1d2d38), ink: .dyn(0x154f6e, 0x9fd0ec))
    static let settings = TabTheme(accent: .dyn(0x56607a, 0xa4acc4), soft: .dyn(0xe8eaf0, 0x2a2d36), ink: .dyn(0x3c4458, 0xc6cbdb))
}

private struct ThemeKey: EnvironmentKey { static let defaultValue = TabTheme.watch }

extension EnvironmentValues {
    var theme: TabTheme {
        get { self[ThemeKey.self] }
        set { self[ThemeKey.self] = newValue }
    }
}

/// A colour that is looked up where it is drawn — so `Paper.accent` is green on
/// Watch, ochre in the Library, purple in Topics, without any view passing it on.
struct ThemeStyle: ShapeStyle {
    enum Part { case accent, soft, ink }
    let part: Part
    func resolve(in environment: EnvironmentValues) -> Color {
        switch part {
        case .accent: return environment.theme.accent
        case .soft:   return environment.theme.soft
        case .ink:    return environment.theme.ink
        }
    }
}

extension Color {
    /// One colour by day, another at night.
    static func dyn(_ light: UInt32, _ dark: UInt32) -> Color {
        #if os(macOS)
        return Color(nsColor: NSColor(name: nil) { ap in
            ap.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? NSColor.hex(dark) : NSColor.hex(light)
        })
        #else
        return Color(uiColor: UIColor { $0.userInterfaceStyle == .dark ? UIColor.hex(dark) : UIColor.hex(light) })
        #endif
    }
}

#if os(macOS)
extension NSColor {
    static func hex(_ v: UInt32) -> NSColor {
        NSColor(srgbRed: CGFloat((v >> 16) & 0xff) / 255, green: CGFloat((v >> 8) & 0xff) / 255,
                blue: CGFloat(v & 0xff) / 255, alpha: 1)
    }
}
#else
extension UIColor {
    static func hex(_ v: UInt32) -> UIColor {
        UIColor(red: CGFloat((v >> 16) & 0xff) / 255, green: CGFloat((v >> 8) & 0xff) / 255,
                blue: CGFloat(v & 0xff) / 255, alpha: 1)
    }
}
#endif

// The web app's palette, carried over: warm paper, one amber for "decide", one
// purple for Together. Every colour has a light AND a dark value — he runs the
// Mac dark. The accent is no longer one green: it is the tab's.
enum Paper {
    static let bg = Color("Bg")
    static let card = Color("Card")
    static let ink = Color("Ink")
    static let inkSoft = Color("InkSoft")
    static let line = Color("Line")
    static let shade = Color("Shade")
    static let accent = ThemeStyle(part: .accent)
    static let accentSoft = ThemeStyle(part: .soft)
    static let accentInk = ThemeStyle(part: .ink)
    static let amber = Color("Amber")
    static let amberSoft = Color("AmberSoft")
    static let pair = Color("Pair")
    static let pairSoft = Color("PairSoft")
    static let danger = Color("Danger")
    /// Text ON a full-colour button: white by day, near-black at night — white
    /// on the light night-green was too faint to read with glasses off.
    static let onAccent = Color("OnAccent")
}

/// Nothing under 15 pt. Glasses may be off.
enum Type {
    static let title = Font.system(size: 28, weight: .bold, design: .rounded)
    static let cardTitle = Font.system(size: 16, weight: .semibold)
    static let body = Font.system(size: 15)
    static let pill = Font.system(size: 15, weight: .medium)
    static let small = Font.system(size: 15)
    static let badge = Font.system(size: 15, weight: .semibold, design: .monospaced)
}

/// A filter pill: quiet when off, green when on, with a little count.
struct Pill: View {
    let title: String
    var count: Int? = nil
    var on = false
    var tint: AnyShapeStyle = AnyShapeStyle(Paper.accent)
    var soft: AnyShapeStyle = AnyShapeStyle(Paper.accentSoft)
    var inkOn: AnyShapeStyle = AnyShapeStyle(Paper.accentInk)
    let identifier: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Text(title).font(Type.pill)
                if let n = count {
                    Text("\(n)").font(Type.small)
                        .foregroundStyle(on ? tint : AnyShapeStyle(Paper.inkSoft))
                }
            }
            .foregroundStyle(on ? inkOn : AnyShapeStyle(Paper.ink))
            .padding(.horizontal, 13)
            .padding(.vertical, 8)
            .background(
                Capsule().fill(on ? soft : AnyShapeStyle(Paper.card))
                    .overlay(Capsule().strokeBorder(on ? tint : AnyShapeStyle(Paper.line), lineWidth: 1))
            )
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(identifier)
    }
}

/// The one full-colour action on a screen. Never grey, never disabled: pressed
/// too early it says what is missing underneath.
struct GoButton: View {
    let title: String
    var tint: AnyShapeStyle = AnyShapeStyle(Paper.accent)
    let identifier: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Paper.onAccent)
                .padding(.horizontal, 22)
                .padding(.vertical, 12)
                .frame(minWidth: 96)
                .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(tint))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(identifier)
    }
}

/// A quiet, bordered button for everything that is not the main action.
struct QuietButton<Label: View>: View {
    let identifier: String
    let action: () -> Void
    @ViewBuilder let label: Label

    var body: some View {
        Button(action: action) {
            label
                .font(Type.pill)
                .foregroundStyle(Paper.ink)
                .padding(.horizontal, 13)
                .padding(.vertical, 9)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Paper.card)
                        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(Paper.line, lineWidth: 1))
                )
                .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(identifier)
    }
}

/// A short message at the bottom, with an optional Undo. Five seconds.
struct Toast: Equatable {
    var text: String
    var undo: (() -> Void)?
    var id = UUID()
    static func == (a: Toast, b: Toast) -> Bool { a.id == b.id }
}

struct ToastView: View {
    let toast: Toast
    let dismiss: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            Text(toast.text).font(Type.body).foregroundStyle(.white)
            if let undo = toast.undo {
                Button {
                    undo(); dismiss()
                } label: {
                    Text("Undo").font(.system(size: 15, weight: .bold)).foregroundStyle(.white)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("wl-undo")
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .background(Capsule().fill(Color.black.opacity(0.82)))
        .accessibilityIdentifier("wl-toast")
    }
}

/// The card frame every video sits in.
struct CardFrame: ViewModifier {
    var tint: AnyShapeStyle = AnyShapeStyle(Paper.line)
    var width: CGFloat = 1
    func body(content: Content) -> some View {
        content
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Paper.card))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(tint, lineWidth: width))
    }
}

// MARK: - Headings in the tab's colour

/// The big name of the screen you are on, in the tab's own colour.
struct ScreenTitle<Trailing: View>: View {
    let title: String
    let identifier: String
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.system(size: 32, weight: .heavy, design: .rounded))
                .foregroundStyle(Paper.accentInk)
                .accessibilityIdentifier(identifier)
            Spacer()
            trailing
        }
    }
}

extension ScreenTitle where Trailing == EmptyView {
    init(title: String, identifier: String) {
        self.init(title: title, identifier: identifier, trailing: { EmptyView() })
    }
}

/// A section heading: small capitals in the tab's colour.
struct SectionTitle: View {
    let text: String
    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 15, weight: .bold))
            .tracking(0.8)
            .foregroundStyle(Paper.accent)
            .padding(.top, 6)
    }
}

/// The screen's paper, with a soft wash of the tab's colour at the top — the
/// first thing the eye meets says which room this is.
struct TabBackground: View {
    @Environment(\.theme) private var theme
    var body: some View {
        ZStack(alignment: .top) {
            Paper.bg
            LinearGradient(colors: [theme.soft, theme.soft.opacity(0)], startPoint: .top, endPoint: .bottom)
                .frame(height: 260)
        }
        .ignoresSafeArea()
    }
}
