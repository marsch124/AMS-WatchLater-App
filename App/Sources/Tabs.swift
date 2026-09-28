import SwiftUI
import WatchLaterCore

/// Five places, the AMS Instructions way (layout A, his pick 2026-09-28).
/// The raw values are the test identifiers, so they stay put when words change.
enum AppTab: String, CaseIterable, Identifiable {
    case watch, library, topics, find, settings
    var id: String { rawValue }

    var title: String {
        switch self {
        case .watch:    return "Watch"
        case .library:  return "Library"
        case .topics:   return "Topics"
        case .find:     return "Find"
        case .settings: return "Settings"
        }
    }

    var theme: TabTheme {
        switch self {
        case .watch:    return .watch
        case .library:  return .library
        case .topics:   return .topics
        case .find:     return .find
        case .settings: return .settings
        }
    }

    var art: [String] {
        switch self {
        case .watch:    return GlyphArt.watch
        case .library:  return GlyphArt.library
        case .topics:   return GlyphArt.topics
        case .find:     return GlyphArt.find
        case .settings: return GlyphArt.settings
        }
    }
}

struct MainView: View {
    @EnvironmentObject private var store: Store
    @State private var tab: AppTab = .watch

    var body: some View {
        ZStack(alignment: .bottom) {
            // Each screen is handed its tab's colours; everything inside
            // follows — headings, pills, buttons, and the pages it opens.
            Group {
                switch tab {
                case .watch:    WatchView()
                case .library:  LibraryTab()
                case .topics:   TopicsTab()
                case .find:     FindTab()
                case .settings: SettingsTab()
                }
            }
            .environment(\.theme, tab.theme)
            .tint(tab.theme.accent)
            .safeAreaInset(edge: .bottom, spacing: 0) { TabBar(tab: $tab, waiting: store.library.open.count) }

            if let t = store.toast {
                ToastView(toast: t) { store.toast = nil }
                    .padding(.bottom, 150)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeOut(duration: 0.2), value: store.toast)
        // The tab bar stays at the bottom, under the keyboard — riding up on
        // top of it (seen in Find, 2026-09-28) hid the results.
        .ignoresSafeArea(.keyboard, edges: .bottom)
    }
}

/// All five colours are always there, dimmed where you are not; the lit one,
/// with a line along its top, is where you are.
struct TabBar: View {
    @Binding var tab: AppTab
    let waiting: Int

    var body: some View {
        HStack(spacing: 0) {
            ForEach(AppTab.allCases) { t in
                let on = tab == t
                Button { tab = t } label: {
                    VStack(spacing: 4) {
                        Glyph(art: t.art, size: 28, weight: on ? 2.1 : 1.9)
                            .foregroundStyle(t.theme.accent)
                            .opacity(on ? 1 : 0.55)
                            .overlay(alignment: .topTrailing) {
                                if t == .watch, waiting > 0 {
                                    Text("\(waiting)")
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundStyle(Paper.onAccent)
                                        .padding(.horizontal, 5).padding(.vertical, 1)
                                        .background(Capsule().fill(t.theme.accent))
                                        .offset(x: 12, y: -6)
                                        .accessibilityIdentifier("tab-watch-badge")
                                }
                            }
                        Text(t.title)
                            .font(.system(size: 15, weight: on ? .bold : .semibold))
                            .foregroundStyle(on ? AnyShapeStyle(t.theme.accent) : AnyShapeStyle(Paper.inkSoft))
                            .lineLimit(1).minimumScaleFactor(0.75)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 9).padding(.bottom, 6)
                    .overlay(alignment: .top) {
                        Capsule().fill(t.theme.accent)
                            .frame(height: 3).padding(.horizontal, 16)
                            .opacity(on ? 1 : 0)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("tab-\(t.rawValue)")
            }
        }
        .padding(.horizontal, 4)
        .background(Paper.card.ignoresSafeArea(edges: .bottom))
        .overlay(alignment: .top) { Rectangle().fill(Paper.line).frame(height: 1) }
    }
}

// MARK: - Opening a card from any tab

struct OpenItem: Identifiable, Equatable { let id: String }

/// A card's page opens in the colour of the tab it was opened from.
struct ItemSheet: ViewModifier {
    @Binding var item: OpenItem?
    @Environment(\.theme) private var theme
    @EnvironmentObject private var store: Store

    func body(content: Content) -> some View {
        content.sheet(item: $item) { o in
            ItemView(itemID: o.id)
                .environmentObject(store)
                .environment(\.theme, theme)
                .tint(theme.accent)
        }
    }
}

extension View {
    func itemSheet(_ item: Binding<OpenItem?>) -> some View { modifier(ItemSheet(item: item)) }
}

// MARK: - A row, for the lists in Library, Topics and Find

struct ThumbImage: View {
    let item: Video
    @EnvironmentObject private var store: Store

    var body: some View {
        ZStack {
            Rectangle().fill(Paper.shade)
            if Thumbs.have(item.thumbKey), let img = Self.load(Thumbs.url(for: item.thumbKey)) {
                img.resizable().aspectRatio(contentMode: .fill)
            } else {
                KindMark(kind: item.kind, size: 26, weight: 2).foregroundStyle(Paper.inkSoft)
            }
        }
        .id(store.thumbTick)
    }

    static func load(_ url: URL) -> Image? {
        #if os(macOS)
        guard let n = NSImage(contentsOf: url) else { return nil }
        return Image(nsImage: n)
        #else
        guard let d = try? Data(contentsOf: url), let u = UIImage(data: d) else { return nil }
        return Image(uiImage: u)
        #endif
    }
}

struct ItemRow<Detail: View>: View {
    let item: Video
    var meta: String? = nil
    let open: () -> Void
    @ViewBuilder var detail: Detail

    var body: some View {
        Button(action: open) {
            HStack(alignment: .top, spacing: 12) {
                ThumbImage(item: item)
                    .frame(width: 112, height: 63)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay(alignment: .bottomTrailing) {
                        if let b = lengthBadge {
                            Text(b).font(.system(size: 14, weight: .semibold, design: .monospaced))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 5).padding(.vertical, 1)
                                .background(RoundedRectangle(cornerRadius: 5).fill(Color.black.opacity(0.78)))
                                .padding(4)
                        }
                    }
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.title.isEmpty ? item.url : item.title)
                        .font(.system(size: 16, weight: .semibold)).foregroundStyle(Paper.ink)
                        .multilineTextAlignment(.leading).lineLimit(2)
                    Text(meta ?? defaultMeta).font(Type.small).foregroundStyle(Paper.inkSoft).lineLimit(2)
                    detail
                }
                Spacer(minLength: 0)
            }
            .padding(10)
            .modifier(CardFrame())
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("wl-open-\(item.id)")
    }

    private var lengthBadge: String? {
        guard let s = item.seconds else { return nil }
        return item.kind.isTimed ? Clock.badge(s) : "\(max(1, s / 60)) min"
    }

    private var defaultMeta: String {
        var parts: [String] = []
        if !item.channel.isEmpty { parts.append(item.channel) }
        if let w = item.watchedAt { parts.append("\(item.doneWord.lowercased()) \(Clock.relative(w))") }
        else { parts.append("saved \(Clock.relative(item.savedAt))") }
        return parts.joined(separator: " · ")
    }
}

extension ItemRow where Detail == KnowledgeLine {
    init(item: Video, meta: String? = nil, open: @escaping () -> Void) {
        self.init(item: item, meta: meta, open: open, detail: { KnowledgeLine(item: item) })
    }
}

/// "3 marks · notes" in the tab's colour — what he has added to a card.
struct KnowledgeLine: View {
    let item: Video
    var body: some View {
        let n = item.marks.count
        let notes = !item.body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        if n > 0 || notes {
            HStack(spacing: 6) {
                PencilMark().foregroundStyle(Paper.accent)
                Text([n > 0 ? (item.kind.isTimed ? "\(n) mark\(n == 1 ? "" : "s")" : "\(n) kept") : nil,
                      notes ? "notes" : nil].compactMap { $0 }.joined(separator: " · "))
                    .font(Type.small).foregroundStyle(Paper.accentInk)
            }
        }
    }
}

/// The friendly note when a tab has nothing to show yet.
struct EmptyNote: View {
    let art: [String]
    let title: String
    let text: String
    let identifier: String
    var body: some View {
        VStack(spacing: 10) {
            Glyph(art: art, size: 48, weight: 2).foregroundStyle(Paper.accent)
            Text(title).font(.system(size: 20, weight: .semibold)).foregroundStyle(Paper.accentInk)
            Text(text).font(Type.body).foregroundStyle(Paper.inkSoft).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 50)
        .padding(.horizontal, 20)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(identifier)
    }
}
