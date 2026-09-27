import SwiftUI

// The web app's palette, carried over: warm paper, one green, one amber for
// "decide", one purple for Together. Every colour has a light AND a dark value
// in the asset catalogue — he runs the Mac dark.
enum Paper {
    static let bg = Color("Bg")
    static let card = Color("Card")
    static let ink = Color("Ink")
    static let inkSoft = Color("InkSoft")
    static let line = Color("Line")
    static let shade = Color("Shade")
    static let accent = Color("Accent")
    static let accentSoft = Color("AccentSoft")
    static let accentInk = Color("AccentInk")
    static let amber = Color("Amber")
    static let amberSoft = Color("AmberSoft")
    static let pair = Color("Pair")
    static let pairSoft = Color("PairSoft")
    static let danger = Color("Danger")
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
    var tint: Color = Paper.accent
    var soft: Color = Paper.accentSoft
    var inkOn: Color = Paper.accentInk
    let identifier: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Text(title).font(Type.pill)
                if let n = count {
                    Text("\(n)").font(Type.small)
                        .foregroundStyle(on ? tint : Paper.inkSoft)
                }
            }
            .foregroundStyle(on ? inkOn : Paper.ink)
            .padding(.horizontal, 13)
            .padding(.vertical, 8)
            .background(
                Capsule().fill(on ? soft : Paper.card)
                    .overlay(Capsule().strokeBorder(on ? tint : Paper.line, lineWidth: 1))
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
    var tint: Color = Paper.accent
    let identifier: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.white)
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
    var tint: Color = Paper.line
    var width: CGFloat = 1
    func body(content: Content) -> some View {
        content
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Paper.card))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(tint, lineWidth: width))
    }
}
