import SwiftUI
import UniformTypeIdentifiers
import WatchLaterCore

/// A frame for every sheet: title, a close mark, scrolling content.
struct SheetFrame<Content: View>: View {
    @Environment(\.dismiss) private var dismiss
    let title: String
    let closeIdentifier: String
    @ViewBuilder let content: Content

    var body: some View {
        ZStack {
            Paper.bg.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Text(title).font(.system(size: 28, weight: .heavy, design: .rounded)).foregroundStyle(Paper.accentInk)
                        Spacer()
                        Button { dismiss() } label: {
                            CrossMark(size: 18).foregroundStyle(Paper.ink)
                                .frame(width: 36, height: 36)
                                .background(Circle().fill(Paper.card).overlay(Circle().strokeBorder(Paper.line)))
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier(closeIdentifier)
                    }
                    content
                }
                .padding(20)
            }
        }
        #if os(macOS)
        .frame(minWidth: 520, minHeight: 480)
        #endif
    }
}

// MARK: - Add

struct AddSheet: View {
    @EnvironmentObject private var store: Store
    @Environment(\.dismiss) private var dismiss
    @State private var text = ""
    @State private var missing: String?
    @State private var working = false

    var body: some View {
        SheetFrame(title: "Add", closeIdentifier: "wl-add-close") {
            Text("One link, a window of links, or a playlist link — paste them here.")
                .font(Type.body).foregroundStyle(Paper.inkSoft)
            TextEditor(text: $text)
                .font(Type.body).foregroundStyle(Paper.ink)
                .scrollContentBackground(.hidden)
                .frame(minHeight: 120)
                .padding(8)
                .background(RoundedRectangle(cornerRadius: 10).fill(Paper.card)
                    .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Paper.line)))
                .accessibilityIdentifier("wl-add-text")
            HStack(spacing: 8) {
                GoButton(title: working ? "Adding…" : "Add", identifier: "wl-add-go") { go() }
                QuietButton(identifier: "wl-add-paste") {
                    if let s = Clipboard.get() { text = text.isEmpty ? s : text + "\n" + s }
                } label: { Text("Paste") }
                #if os(macOS)
                QuietButton(identifier: "wl-add-safari") { takeSafari() } label: { Text("Take Safari's page") }
                #endif
            }
            if let missing {
                Text(missing).font(Type.body).foregroundStyle(Paper.amber)
                    .accessibilityIdentifier("wl-add-missing")
            }
            #if os(iOS)
            Text("From YouTube itself: Share → More → WatchLater. No need to come here.")
                .font(Type.body).foregroundStyle(Paper.inkSoft)
            #endif
        }
    }

    private func go() {
        let links = YouTube.links(in: text)
        guard !links.isEmpty || !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            missing = "Paste a link first."
            return
        }
        working = true
        Task {
            let r = await store.add(text: text)
            working = false
            store.say(r.line)
            dismiss()
        }
    }

    #if os(macOS)
    /// Asks Safari for its front tab. macOS asks him once whether that is allowed.
    private func takeSafari() {
        let script = NSAppleScript(source: "tell application \"Safari\" to get URL of front document")
        var err: NSDictionary?
        if let out = script?.executeAndReturnError(&err).stringValue, !out.isEmpty {
            text = text.isEmpty ? out : text + "\n" + out
            missing = nil
        } else {
            missing = "Safari did not answer. Is a page open there, and is WatchLater allowed to ask (System Settings › Privacy › Automation)?"
        }
    }
    #endif
}

// MARK: - Plan an evening

struct PlanSheet: View {
    @EnvironmentObject private var store: Store
    let pool: [Video]
    let done: ([Video]) -> Void
    @State private var budget = 45
    @State private var picks: [Video] = []

    var body: some View {
        SheetFrame(title: "Plan an evening", closeIdentifier: "wl-plan-close") {
            Text("How long have you got? The app fills the time from what is on screen.")
                .font(Type.body).foregroundStyle(Paper.inkSoft)
            FlowRow(spacing: 8) {
                ForEach(Planner.budgets, id: \.self) { m in
                    Pill(title: m >= 60 ? (m % 60 == 0 ? "\(m / 60) h" : "\(m / 60) h \(m % 60)") : "\(m) min",
                         on: budget == m, identifier: "wl-budget-\(m)") { budget = m; make() }
                }
            }
            if picks.isEmpty {
                Text(pool.isEmpty ? "Nothing on screen to plan with." : "Pick a time.").font(Type.body).foregroundStyle(Paper.inkSoft)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(picks.enumerated()), id: \.element.id) { i, v in
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Text("\(i + 1).").font(Type.body).foregroundStyle(Paper.inkSoft)
                            Text(v.title).font(Type.body).foregroundStyle(Paper.ink).lineLimit(2)
                            Spacer()
                            Text(Clock.badge(v.seconds) ?? "").font(Type.badge).foregroundStyle(Paper.inkSoft)
                        }
                    }
                    Text("\(picks.count) videos · \(Clock.total(picks))").font(Type.pill).foregroundStyle(Paper.accentInk)
                }
                .padding(14).modifier(CardFrame())
                HStack(spacing: 8) {
                    GoButton(title: "Show these", identifier: "wl-plan-show") { done(picks) }
                    QuietButton(identifier: "wl-plan-retry") { make() } label: { Text("Try another") }
                }
            }
        }
        .onAppear { make() }
    }

    private func make() { picks = Planner.plan(minutes: budget, from: pool) }
}

struct JSONFile: FileDocument {
    static var readableContentTypes: [UTType] { [.json, .commaSeparatedText] }
    var data: Data
    init(data: Data) { self.data = data }
    init(configuration: ReadConfiguration) throws { data = configuration.file.regularFileContents ?? Data() }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper { FileWrapper(regularFileWithContents: data) }
}

// MARK: - How it works / What is new

struct GuideSheet: View {
    let page: SettingsTab.Page

    var body: some View {
        switch page {
        case .how:
            SheetFrame(title: "How it works", closeIdentifier: "wl-guide-close") {
                ForEach(Guide.howItWorks, id: \.0) { h, body in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(h).font(.system(size: 17, weight: .semibold)).foregroundStyle(Paper.accentInk)
                        Text(body).font(Type.body).foregroundStyle(Paper.ink)
                    }
                    .padding(.bottom, 4)
                }
            }
        case .new:
            SheetFrame(title: "What's new", closeIdentifier: "wl-guide-close") {
                Text("Version \(Guide.appVersion) · build \(Guide.build)").font(Type.body).foregroundStyle(Paper.inkSoft)
                ForEach(Guide.releases) { r in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("v\(r.version)").font(Type.pill).foregroundStyle(Paper.accentInk)
                            Text(r.date).font(Type.small).foregroundStyle(Paper.inkSoft)
                        }
                        Text(r.headline).font(.system(size: 17, weight: .semibold)).foregroundStyle(Paper.ink)
                        ForEach(r.lines, id: \.self) { l in
                            HStack(alignment: .top, spacing: 8) {
                                Circle().fill(Paper.accent).frame(width: 6, height: 6).padding(.top, 7)
                                Text(l).font(Type.body).foregroundStyle(Paper.ink)
                            }
                        }
                    }
                    .padding(14).modifier(CardFrame())
                }
            }
        case .share:
            SheetFrame(title: "Save from the phone", closeIdentifier: "wl-guide-close") {
                ForEach(Guide.shareSteps, id: \.self) { step in
                    HStack(alignment: .top, spacing: 10) {
                        Circle().fill(Paper.accent).frame(width: 8, height: 8).padding(.top, 7)
                        Text(step).font(.system(size: 17)).foregroundStyle(Paper.ink)
                    }
                }
            }
        }
    }
}

/// "Link to…": every other card, newest first, with a search box. One tap
/// links and closes.
struct LinkPicker: View {
    let from: Video
    let pick: (String) -> Void
    @EnvironmentObject private var store: Store
    @State private var query = ""

    var body: some View {
        let already = Set(from.links)
        let needle = Shelf.fold(query)
        let cards = store.library.live
            .filter { $0.id != from.id && !already.contains($0.id) }
            .filter { needle.count < 2 || Shelf.fold($0.title + " " + $0.channel + " " + $0.tags.joined(separator: " ")).contains(needle) }
            .sorted { ($0.watchedAt ?? $0.savedAt) > ($1.watchedAt ?? $1.savedAt) }
        SheetFrame(title: "Link to…", closeIdentifier: "wl-link-close") {
            HStack(spacing: 10) {
                Glyph(art: GlyphArt.find, size: 20).foregroundStyle(Paper.accent)
                TextField("Title, channel or tag", text: $query)
                    .textFieldStyle(.plain).font(.system(size: 17)).foregroundStyle(Paper.ink)
                    .accessibilityIdentifier("wl-link-find")
            }
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 12).fill(Paper.card)
                .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Paper.accent, lineWidth: 1.4)))
            if cards.isEmpty {
                Text(needle.count < 2 ? "Nothing else is saved yet." : "No card matches “\(query)”.")
                    .font(Type.body).foregroundStyle(Paper.inkSoft)
            }
            ForEach(cards.prefix(80)) { v in
                ItemRow(item: v) { pick(v.id) }
                    .accessibilityIdentifier("wl-link-pick-\(v.id)")
            }
        }
    }
}
