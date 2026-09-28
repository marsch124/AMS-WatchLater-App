import SwiftUI
import UniformTypeIdentifiers
import WatchLaterCore

/// The same jacket for every list tab: the tab's wash, a scrolling column,
/// room at the bottom for the tab bar.
struct TabScreen<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        ZStack {
            TabBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 12) { content }
                    .padding(.horizontal, 16)
                    .padding(.top, 10)
                    .padding(.bottom, 30)
                    .frame(maxWidth: 820, alignment: .leading)
                    .frame(maxWidth: .infinity)
            }
            .scrollDismissesKeyboard(.interactively)
        }
    }
}

// MARK: - Library (ochre)

/// What he has watched or read — kept, with its marks and notes.
struct LibraryTab: View {
    @EnvironmentObject private var store: Store
    @State private var filter: LibraryShelf.Filter = .all
    @State private var kind: ItemKind?
    @State private var opened: OpenItem?

    var body: some View {
        let groups = LibraryShelf.groups(store.library, filter: filter, kind: kind)
        let doneCount = store.library.live.filter { $0.watchedAt != nil }.count
        TabScreen {
            ScreenTitle(title: "Library", identifier: "wl-screen-library") {
                let marks = LibraryShelf.markCount(store.library)
                Text("\(doneCount)\(marks > 0 ? " · \(marks) mark\(marks == 1 ? "" : "s")" : "")")
                    .font(Type.small).foregroundStyle(Paper.accentInk)
            }
            FlowRow(spacing: 8) {
                ForEach(LibraryShelf.Filter.allCases) { f in
                    Pill(title: f.title, on: filter == f && kind == nil, identifier: "wl-lib-\(f.rawValue)") {
                        filter = f; kind = nil
                    }
                }
                let kinds = Shelf.kinds(store.library, done: true)
                if kinds.count > 1 {
                    ForEach(kinds, id: \.kind) { k in
                        Pill(title: k.kind.title, count: k.count, on: kind == k.kind,
                             identifier: "wl-lib-kind-\(k.kind.rawValue)") { kind = k.kind; filter = .all }
                    }
                }
            }
            if groups.isEmpty {
                EmptyNote(art: GlyphArt.library,
                          title: doneCount == 0 ? "Nothing here yet" : "Nothing with notes yet",
                          text: doneCount == 0
                            ? "When you tick something as Watched or Read, it comes here — with every mark and note you made."
                            : "Open something in the Library and mark a moment or write a note.",
                          identifier: "wl-library-empty")
            }
            ForEach(groups) { g in
                SectionTitle(text: g.title)
                ForEach(g.items) { v in
                    ItemRow(item: v) { opened = OpenItem(id: v.id) }
                }
            }
        }
        .itemSheet($opened)
    }
}

// MARK: - Topics (purple)

/// His subjects. For now a topic is a tag; linking notes to each other comes
/// with step 3.
struct TopicsTab: View {
    @EnvironmentObject private var store: Store
    @State private var path: [String] = []

    var body: some View {
        NavigationStack(path: $path) {
            let topics = Topics.all(store.library)
            TabScreen {
                ScreenTitle(title: "Topics", identifier: "wl-screen-topics") {
                    Text("\(topics.count)").font(Type.small).foregroundStyle(Paper.accentInk)
                }
                if topics.isEmpty {
                    EmptyNote(art: GlyphArt.topics, title: "No topics yet",
                              text: "Every tag you give a card becomes a topic here, collecting its videos, articles and marks. Open a card and press Add tags.",
                              identifier: "wl-topics-empty")
                }
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 300), spacing: 12)], spacing: 12) {
                    ForEach(topics) { t in
                        NavigationLink(value: t.id) { TopicTile(topic: t) }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("wl-topic-\(t.id)")
                    }
                }
            }
            .navigationDestination(for: String.self) { id in
                TopicPage(topicID: id)
            }
            #if os(iOS)
            .toolbar(.hidden, for: .navigationBar)
            #endif
        }
    }
}

struct TopicTile: View {
    let topic: Topic
    var body: some View {
        HStack(spacing: 14) {
            let pics = Array(topic.items.prefix(4))
            // Four squares, two by two, laid out by hand — a lazy grid inside a
            // row measured itself wrong and scattered them (seen 2026-09-28).
            VStack(spacing: 3) {
                ForEach(0..<2, id: \.self) { r in
                    HStack(spacing: 3) {
                        ForEach(0..<2, id: \.self) { c in
                            let i = r * 2 + c
                            Group {
                                if i < pics.count { ThumbImage(item: pics[i]) } else { Rectangle().fill(Paper.accentSoft) }
                            }
                            .frame(width: 38, height: 38).clipped()
                        }
                    }
                }
            }
            .frame(width: 79, height: 79)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            VStack(alignment: .leading, spacing: 4) {
                Text(topic.name).font(.system(size: 19, weight: .bold, design: .rounded)).foregroundStyle(Paper.accentInk)
                Text(topic.summary).font(Type.small).foregroundStyle(Paper.inkSoft)
                if topic.waiting > 0 {
                    Text("\(topic.waiting) waiting").font(Type.small).foregroundStyle(Paper.accent)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .modifier(CardFrame())
        .contentShape(Rectangle())
    }
}

struct TopicPage: View {
    let topicID: String
    @EnvironmentObject private var store: Store
    @Environment(\.dismiss) private var dismiss
    @State private var opened: OpenItem?

    var body: some View {
        let topic = Topics.all(store.library).first { $0.id == topicID }
        TabScreen {
            Button { dismiss() } label: {
                Text("‹ Topics").font(Type.pill).foregroundStyle(Paper.accent)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("wl-topic-back")
            if let topic {
                ScreenTitle(title: topic.name, identifier: "wl-screen-topic")
                Text(topic.summary).font(Type.body).foregroundStyle(Paper.inkSoft)
                let waiting = topic.items.filter(\.isOpen), done = topic.items.filter { !$0.isOpen }
                if !waiting.isEmpty {
                    SectionTitle(text: "Waiting · \(waiting.count)")
                    ForEach(waiting) { v in ItemRow(item: v) { opened = OpenItem(id: v.id) } }
                }
                if !done.isEmpty {
                    SectionTitle(text: "In the Library · \(done.count)")
                    ForEach(done) { v in ItemRow(item: v) { opened = OpenItem(id: v.id) } }
                }
            } else {
                Text("This topic has no cards any more.").font(Type.body).foregroundStyle(Paper.inkSoft)
            }
        }
        #if os(iOS)
        .toolbar(.hidden, for: .navigationBar)
        #endif
        .itemSheet($opened)
    }
}

// MARK: - Find (blue)

/// One box that searches everything — waiting and Library, titles, his marks,
/// his notes, tags — and says where it found the words.
struct FindTab: View {
    @EnvironmentObject private var store: Store
    @Environment(\.theme) private var theme
    @State private var query = ""
    @State private var filter = FindFilter()
    @State private var opened: OpenItem?
    @FocusState private var focused: Bool

    private var searching: Bool { query.trimmingCharacters(in: .whitespaces).count >= 2 }

    var body: some View {
        let hits = Finder.search(store.library, query, transcripts: store.transcripts, filter: filter)
        TabScreen {
            ScreenTitle(title: "Find", identifier: "wl-screen-find")
            HStack(spacing: 10) {
                Glyph(art: GlyphArt.find, size: 22).foregroundStyle(Paper.accent)
                TextField("Titles, notes, what was said", text: $query)
                    .textFieldStyle(.plain).font(.system(size: 17)).foregroundStyle(Paper.ink)
                    .focused($focused)
                    .submitLabel(.search)
                    .accessibilityIdentifier("wl-find-field")
                if !query.isEmpty {
                    Button { query = "" } label: { CrossMark(size: 15).foregroundStyle(Paper.inkSoft) }
                        .buttonStyle(.plain).accessibilityIdentifier("wl-find-clear")
                }
            }
            .padding(.horizontal, 14).padding(.vertical, 13)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Paper.card)
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Paper.accent, lineWidth: 1.5)))

            savedRow
            if searching { filterRow }

            if !searching {
                tagShortcuts
            } else if hits.isEmpty {
                EmptyNote(art: GlyphArt.find, title: "Nothing mentions “\(query)”",
                          text: "Find looks in titles, channels, tags, your marks, your notes and what was said in the videos — in the list and in the Library.",
                          identifier: "wl-find-none")
            } else {
                let waiting = hits.filter { $0.item.isOpen }, done = hits.filter { !$0.item.isOpen }
                if !waiting.isEmpty {
                    SectionTitle(text: "Waiting · \(waiting.count)")
                    ForEach(waiting) { h in hitRow(h) }
                }
                if !done.isEmpty {
                    SectionTitle(text: "In the Library · \(done.count)")
                    ForEach(done) { h in hitRow(h) }
                }
            }
        }
        .itemSheet($opened)
    }

    /// Saved searches: one tap runs them again. The current one can be saved.
    @ViewBuilder
    private var savedRow: some View {
        let saved = store.library.liveSearches
        let isSaved = saved.contains { Shelf.fold($0.query) == Shelf.fold(query) }
        if !saved.isEmpty || (searching && !isSaved) {
            FlowRow(spacing: 8) {
                ForEach(saved) { q in
                    HStack(spacing: 0) {
                        Pill(title: q.query, on: Shelf.fold(q.query) == Shelf.fold(query),
                             identifier: "wl-saved-\(q.query)") { query = q.query }
                        if Shelf.fold(q.query) == Shelf.fold(query) {
                            Button { store.removeSearch(q) } label: {
                                CrossMark(size: 13).foregroundStyle(Paper.danger).frame(width: 30, height: 30)
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("wl-saved-remove")
                        }
                    }
                }
                if searching && !isSaved {
                    Button { store.saveSearch(query) } label: {
                        HStack(spacing: 6) { PlusMark(size: 14, weight: 2.4); Text("Save this search") }
                            .font(Type.pill).foregroundStyle(Paper.accentInk)
                            .padding(.horizontal, 13).padding(.vertical, 8)
                            .background(Capsule().strokeBorder(Paper.accent, style: StrokeStyle(lineWidth: 1.2, dash: [4, 3])))
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("wl-save-search")
                }
            }
        }
    }

    /// Narrow it down: where, what kind, only what he wrote about.
    private var filterRow: some View {
        FlowRow(spacing: 8) {
            ForEach(FindFilter.Where.allCases) { w in
                Pill(title: w.title, on: filter.place == w, identifier: "wl-find-where-\(w.rawValue)") { filter.place = w }
            }
            let kinds = ItemKind.allCases.filter { k in store.library.live.contains { $0.kind == k } }
            if kinds.count > 1 {
                ForEach(kinds) { k in
                    Pill(title: k.title, on: filter.kind == k, identifier: "wl-find-kind-\(k.rawValue)") {
                        filter.kind = filter.kind == k ? nil : k
                    }
                }
            }
            Pill(title: "With notes", on: filter.withNotes, identifier: "wl-find-notes") { filter.withNotes.toggle() }
        }
    }

    @ViewBuilder
    private var tagShortcuts: some View {
        let topics = Topics.all(store.library)
        if !topics.isEmpty {
            SectionTitle(text: "Your topics")
            FlowRow(spacing: 8) {
                ForEach(topics) { t in
                    Pill(title: t.name, count: t.items.count, identifier: "wl-find-tag-\(t.id)") { query = t.name }
                }
            }
        }
        Text("Type two letters or more. Find also searches what was said in your videos. Accents do not matter — hjarnans finds hjärnans.")
            .font(Type.body).foregroundStyle(Paper.inkSoft).padding(.top, 6)
    }

    private func hitRow(_ h: Hit) -> some View {
        ItemRow(item: h.item, open: { opened = OpenItem(id: h.item.id, start: startSecond(h.place)) }) {
            if h.place != .title {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    placeLabel(h.place)
                    highlighted(h)
                        .font(Type.small).lineLimit(2)
                }
                if h.alsoSaid > 0 {
                    Text("and \(h.alsoSaid) more time\(h.alsoSaid == 1 ? "" : "s") in the video")
                        .font(Type.small).foregroundStyle(Paper.inkSoft)
                }
            }
        }
        .accessibilityIdentifier("wl-hit-\(h.item.id)")
    }

    /// A moment to open at: where it was said, or where the mark is.
    private func startSecond(_ p: Hit.Place) -> Int? {
        switch p {
        case .said(let s): return s
        case .mark(let s): return s
        default: return nil
        }
    }

    @ViewBuilder
    private func placeLabel(_ p: Hit.Place) -> some View {
        switch p {
        case .mark(let s):
            Text(s.flatMap(Clock.badge) ?? "mark")
                .font(.system(size: 14, weight: .semibold, design: .monospaced))
                .foregroundStyle(Paper.accentInk)
                .padding(.horizontal, 6).padding(.vertical, 1)
                .background(Capsule().fill(Paper.accentSoft))
        case .note, .body: Text("note").font(.system(size: 14, weight: .semibold)).foregroundStyle(Paper.accent)
        case .tag:         Text("tag").font(.system(size: 14, weight: .semibold)).foregroundStyle(Paper.accent)
        case .channel:     Text("by").font(.system(size: 14, weight: .semibold)).foregroundStyle(Paper.accent)
        case .blurb:       Text("about").font(.system(size: 14, weight: .semibold)).foregroundStyle(Paper.accent)
        case .said(let s):
            Text("said \(Clock.badge(s) ?? "")")
                .font(.system(size: 14, weight: .semibold, design: .monospaced))
                .foregroundStyle(Paper.accentInk)
                .padding(.horizontal, 6).padding(.vertical, 1)
                .background(Capsule().fill(Paper.accentSoft))
        case .title:       EmptyView()
        }
    }

    /// The snippet with the matched words lit in the tab's colour.
    private func highlighted(_ h: Hit) -> Text {
        var a = AttributedString(h.snippet)
        a.foregroundColor = nil
        if let r = a.range(of: h.match, options: [.caseInsensitive]) {
            a[r].backgroundColor = theme.soft
            a[r].foregroundColor = theme.ink
            a[r].font = .system(size: 15, weight: .semibold)
        }
        return Text(a).foregroundColor(Paper.inkSoft)
    }
}

// MARK: - Settings (slate)

struct SettingsTab: View {
    @EnvironmentObject private var store: Store
    @State private var importing = false
    @State private var exporting = false
    @State private var report: String?
    @State private var page: Page?

    enum Page: String, Identifiable { case how, new, share; var id: String { rawValue } }

    var body: some View {
        TabScreen {
            ScreenTitle(title: "Settings", identifier: "wl-screen-settings")

            SectionTitle(text: "Your data")
            SettingsGroup {
                SettingsRow(art: GlyphArt.cloud, title: "Where the list lives", value: store.syncPlace, identifier: "wl-set-place")
                SettingsRow(art: GlyphArt.watch, title: "Waiting",
                            value: "\(store.library.open.count) · \(Clock.total(store.library.open))", identifier: "wl-set-waiting")
                SettingsRow(art: GlyphArt.library, title: "In the Library",
                            value: "\(store.library.live.filter { $0.watchedAt != nil }.count)", identifier: "wl-set-library")
                SaidRow(fetcher: store.fetcher)
                SettingsRow(art: GlyphArt.exportOut, title: "Back up now",
                            value: "\(store.backups().count) safety cop\(store.backups().count == 1 ? "y" : "ies")",
                            identifier: "wl-export") { exporting = true }
                SettingsRow(art: GlyphArt.importIn, title: "Import watchlater.json", value: "old app",
                            identifier: "wl-import") { importing = true }
            }
            if let report {
                Text(report).font(Type.body).foregroundStyle(Paper.accentInk).accessibilityIdentifier("wl-data-report")
            }

            SectionTitle(text: "Saving")
            SettingsGroup {
                SettingsRow(art: GlyphArt.watch, title: "Save from the phone", value: "Share sheet", identifier: "wl-set-share") { page = .share }
            }

            SectionTitle(text: "About")
            SettingsGroup {
                SettingsRow(art: GlyphArt.book, title: "How it works", identifier: "wl-set-how") { page = .how }
                SettingsRow(art: GlyphArt.sprout, title: "What's new", value: "v\(Guide.appVersion) · build \(Guide.build)",
                            identifier: "wl-version") { page = .new }
            }
        }
        .sheet(item: $page) { p in
            GuideSheet(page: p).environment(\.theme, .settings).tint(TabTheme.settings.accent)
        }
        .fileImporter(isPresented: $importing, allowedContentTypes: [.json]) { result in
            guard case .success(let url) = result else { return }
            let ok = url.startAccessingSecurityScopedResource()
            defer { if ok { url.stopAccessingSecurityScopedResource() } }
            guard let data = try? Data(contentsOf: url) else { report = "Could not read that file."; return }
            let n = store.importOld(data)
            report = n < 0 ? "That is not a WatchLater file." : (n == 0 ? "Nothing new in it — every card was already here." : "Imported \(n).")
        }
        .fileExporter(isPresented: $exporting, document: JSONFile(data: store.exportData()),
                      contentType: .json, defaultFilename: "watchlater-\(ISO8601DateFormatter.day.string(from: Date()))") { r in
            if case .success = r { report = "Backup written." }
        }
    }
}

struct SettingsGroup<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        VStack(spacing: 0) { content }
            .modifier(CardFrame())
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

/// How many videos Find can search by what was said — and a way to look again.
private struct SaidRow: View {
    @EnvironmentObject var store: Store
    @ObservedObject var fetcher: TranscriptFetcher

    var body: some View {
        let videos = store.library.live.filter { $0.kind == .video && !$0.countsAsShort }
        let have = videos.filter { $0.videoId.map { store.transcripts[$0] != nil } ?? false }.count
        let busy = fetcher.current != nil
        SettingsRow(art: GlyphArt.find, title: "What was said",
                    value: busy ? "\(have) of \(videos.count) · listening, \(fetcher.waiting + 1) to go"
                                : "\(have) of \(videos.count) videos",
                    identifier: "wl-set-said") { store.lookForTranscripts(force: true) }
    }
}

struct SettingsRow: View {
    let art: [String]
    let title: String
    var value: String? = nil
    let identifier: String
    var action: (() -> Void)? = nil

    var body: some View {
        let row = HStack(spacing: 12) {
            Glyph(art: art, size: 24).foregroundStyle(Paper.accent)
            Text(title).font(.system(size: 16)).foregroundStyle(Paper.ink)
            Spacer(minLength: 8)
            if let value { Text(value).font(Type.small).foregroundStyle(Paper.inkSoft).lineLimit(1) }
            if action != nil { Text("›").font(.system(size: 20, weight: .semibold)).foregroundStyle(Paper.accent) }
        }
        .padding(.horizontal, 14).padding(.vertical, 13)
        .overlay(alignment: .bottom) { Rectangle().fill(Paper.line).frame(height: 1).padding(.leading, 50) }
        .contentShape(Rectangle())
        if let action {
            Button(action: action) { row }.buttonStyle(.plain).accessibilityIdentifier(identifier)
        } else {
            row.accessibilityElement(children: .combine).accessibilityIdentifier(identifier)
        }
    }
}
