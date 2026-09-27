import SwiftUI
import WatchLaterCore

/// The one screen: what to watch, in the time you have.
struct RootView: View {
    @EnvironmentObject private var store: Store
    @State private var shelf = Shelf()
    @State private var picked = Set<String>()          // ids ticked for a bulk action
    @State private var plan: [Video]? = nil
    @State private var sheet: Sheet?
    @State private var showSorts = false

    enum Sheet: Identifiable {
        case add, plan, data, guide
        var id: Int { hashValue }
    }

    private var rows: [Video] {
        if let plan { return plan }
        return shelf.apply(to: store.library)
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            Paper.bg.ignoresSafeArea()

            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        header
                        buckets
                        arrange
                        if shelf.togetherOnly { togetherBar }
                        if let plan { planBar(plan) }
                        if !picked.isEmpty { pickedBar }
                        cards
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 10)
                    .padding(.bottom, 90)
                }
                .scrollDismissesKeyboard(.interactively)
            }

            VStack(spacing: 10) {
                if let t = store.toast {
                    ToastView(toast: t) { store.toast = nil }
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                addBar
            }
            .padding(.bottom, 8)
        }
        .animation(.easeOut(duration: 0.2), value: store.toast)
        .sheet(item: $sheet) { which in
            switch which {
            case .add:   AddSheet()
            case .plan:  PlanSheet(pool: shelf.apply(to: store.library)) { plan = $0; sheet = nil }
            case .data:  DataSheet()
            case .guide: GuideSheet()
            }
        }
        .onChange(of: store.library) { _, _ in
            // A card that vanished from the list leaves the selection too.
            picked = picked.filter { id in store.library.live.contains { $0.id == id } }
        }
    }

    // MARK: Header

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("Watch later").font(Type.title).foregroundStyle(Paper.ink)
            Spacer()
            let open = store.library.open
            Text("\(open.count) · \(Clock.total(open))")
                .font(Type.small).foregroundStyle(Paper.inkSoft)
                .accessibilityIdentifier("wl-tally")
            Button { sheet = .guide } label: {
                Text("v\(Guide.appVersion)").font(Type.small).foregroundStyle(Paper.inkSoft)
                    .padding(.horizontal, 9).padding(.vertical, 3)
                    .overlay(Capsule().strokeBorder(Paper.line))
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("wl-version")
            QuietButton(identifier: "wl-data") { sheet = .data } label: { Text("Your data") }
        }
    }

    // MARK: Pills

    private var buckets: some View {
        let counts = Shelf.counts(store.library)
        let shorts = Shelf.shortsCount(store.library)
        let together = Shelf.togetherCount(store.library)
        return FlowRow(spacing: 8) {
            Text("I have").font(Type.small).foregroundStyle(Paper.inkSoft)
            ForEach(Bucket.allCases) { b in
                Pill(title: b.title, count: counts[b],
                     on: !shelf.showWatched && !shelf.shortsOnly && shelf.bucket == b,
                     identifier: "wl-bucket-\(b.rawValue)") {
                    shelf.bucket = b; shelf.showWatched = false; shelf.shortsOnly = false; plan = nil
                }
            }
            if shorts > 0 {
                Pill(title: "Shorts", count: shorts, on: shelf.shortsOnly, identifier: "wl-shorts") {
                    shelf.shortsOnly.toggle(); shelf.showWatched = false; plan = nil
                }
            }
            if together > 0 {
                Pill(title: "Together", count: together, on: shelf.togetherOnly,
                     tint: Paper.pair, soft: Paper.pairSoft, inkOn: Paper.pair, identifier: "wl-together") {
                    shelf.togetherOnly.toggle(); plan = nil
                }
            }
            Pill(title: "Watched", on: shelf.showWatched, identifier: "wl-watched") {
                shelf.showWatched.toggle(); shelf.shortsOnly = false; plan = nil
            }
        }
    }

    private var arrange: some View {
        FlowRow(spacing: 8) {
            HStack(spacing: 6) {
                SearchMark().foregroundStyle(Paper.inkSoft)
                TextField("Search", text: $shelf.search)
                    .textFieldStyle(.plain).font(Type.body).foregroundStyle(Paper.ink)
                    .frame(minWidth: 120, maxWidth: 200)
                    .accessibilityIdentifier("wl-search")
                    .onChange(of: shelf.search) { _, _ in plan = nil }
                if !shelf.search.isEmpty {
                    Button { shelf.search = "" } label: { CrossMark(size: 14).foregroundStyle(Paper.inkSoft) }
                        .buttonStyle(.plain).accessibilityIdentifier("wl-search-clear")
                }
            }
            .padding(.horizontal, 12).padding(.vertical, 7)
            .background(Capsule().fill(Paper.card).overlay(Capsule().strokeBorder(Paper.line)))

            Menu {
                ForEach(Sort.allCases) { s in
                    Button(s.title) { shelf.sort = s }
                }
            } label: {
                HStack(spacing: 6) { Text("Sort · \(shelf.sort.title)").font(Type.pill) }
                    .foregroundStyle(Paper.ink)
                    .padding(.horizontal, 13).padding(.vertical, 8)
                    .background(Capsule().fill(Paper.card).overlay(Capsule().strokeBorder(Paper.line)))
            }
            .menuStyle(.button).buttonStyle(.plain)
            .accessibilityIdentifier("wl-sort")

            if let c = shelf.channel {
                Pill(title: c, on: true, identifier: "wl-channel-clear") { shelf.channel = nil }
            }
            if let t = shelf.tag {
                Pill(title: t, on: true, identifier: "wl-tag-clear") { shelf.tag = nil }
            }
            let tags = Shelf.tags(store.library)
            if shelf.tag == nil, !tags.isEmpty {
                Menu {
                    ForEach(tags, id: \.tag) { t in Button("\(t.tag) · \(t.count)") { shelf.tag = t.tag } }
                } label: {
                    HStack(spacing: 6) { TagMark(); Text("Tags").font(Type.pill) }
                        .foregroundStyle(Paper.ink)
                        .padding(.horizontal, 13).padding(.vertical, 8)
                        .background(Capsule().fill(Paper.card).overlay(Capsule().strokeBorder(Paper.line)))
                }
                .menuStyle(.button).buttonStyle(.plain)
                .accessibilityIdentifier("wl-tags")
            }

            if !shelf.showWatched {
                Pill(title: "Plan an evening", on: plan != nil, identifier: "wl-plan") {
                    if plan != nil { plan = nil } else { sheet = .plan }
                }
            }
        }
    }

    // MARK: Bars

    private var togetherBar: some View {
        let vs = rows
        return VStack(alignment: .leading, spacing: 10) {
            Text(vs.isEmpty ? "Mark a video with the two heads to watch it together."
                            : "One link plays these \(vs.count) in order — send it wherever you like.")
                .font(Type.body).foregroundStyle(Paper.ink)
            if !vs.isEmpty {
                HStack(spacing: 8) {
                    CopyButton(title: "Copy the link", text: Together.link(for: vs) ?? "", identifier: "wl-together-link")
                    CopyButton(title: "Copy a message", text: Together.message(for: vs), identifier: "wl-together-message")
                }
            }
        }
        .padding(14)
        .modifier(CardFrame(tint: Paper.pair))
        .accessibilityIdentifier("wl-together-bar")
    }

    private func planBar(_ vs: [Video]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(vs.isEmpty ? "Nothing on screen fits that time."
                            : "An evening of \(vs.count): \(Clock.total(vs)).")
                .font(Type.body).foregroundStyle(Paper.ink)
            HStack(spacing: 8) {
                if let link = Together.link(for: vs), let u = URL(string: link) {
                    Link(destination: u) {
                        Text("Open as one playlist").font(Type.pill).foregroundStyle(.white)
                            .padding(.horizontal, 13).padding(.vertical, 9)
                            .background(RoundedRectangle(cornerRadius: 10).fill(Paper.accent))
                    }
                    .accessibilityIdentifier("wl-plan-open")
                    CopyButton(title: "Copy the link", text: link, identifier: "wl-plan-link")
                }
                QuietButton(identifier: "wl-plan-again") { sheet = .plan } label: { Text("Try another") }
                QuietButton(identifier: "wl-plan-clear") { plan = nil } label: { CrossMark(size: 14) }
            }
        }
        .padding(14)
        .modifier(CardFrame(tint: Paper.accent))
    }

    private var pickedBar: some View {
        let vs = rows.filter { picked.contains($0.id) }
        return HStack(spacing: 8) {
            Text("\(vs.count) picked").font(Type.body).foregroundStyle(Paper.ink)
            Spacer()
            QuietButton(identifier: "wl-picked-watched") { vs.forEach { store.setWatched($0, true) }; picked = [] } label: {
                HStack(spacing: 6) { TickMark(size: 15); Text("Watched") }
            }
            QuietButton(identifier: "wl-picked-together") { vs.forEach { store.toggleTogether($0) }; picked = [] } label: {
                HStack(spacing: 6) { PairMark(size: 15); Text("Together") }
            }
            QuietButton(identifier: "wl-picked-check") { Task { for v in vs { await store.check(v) } }; picked = [] } label: {
                Text("Check")
            }
            Button { store.bin(vs); picked = [] } label: {
                HStack(spacing: 6) { BinMark(size: 15); Text("Remove") }
                    .font(Type.pill).foregroundStyle(.white)
                    .padding(.horizontal, 13).padding(.vertical, 9)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Paper.danger))
            }
            .buttonStyle(.plain).accessibilityIdentifier("wl-picked-remove")
            QuietButton(identifier: "wl-picked-clear") { picked = [] } label: { CrossMark(size: 14) }
        }
        .padding(12)
        .modifier(CardFrame())
    }

    // MARK: Cards

    private var cards: some View {
        let vs = rows
        return Group {
            if vs.isEmpty {
                emptyNote
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 250, maximum: 340), spacing: 14, alignment: .top)],
                          alignment: .leading, spacing: 14) {
                    ForEach(vs) { v in
                        CardView(video: v,
                                 picked: picked.contains(v.id),
                                 togglePick: { if picked.contains(v.id) { picked.remove(v.id) } else { picked.insert(v.id) } },
                                 pickChannel: { shelf.channel = v.channel; plan = nil },
                                 pickTag: { shelf.tag = $0; plan = nil })
                    }
                }
            }
        }
    }

    private var emptyNote: some View {
        VStack(spacing: 10) {
            PlayMark(size: 44, weight: 3).foregroundStyle(Paper.accent)
            Text(store.library.open.isEmpty ? "Nothing waiting." : "Nothing fits here.")
                .font(.system(size: 20, weight: .semibold)).foregroundStyle(Paper.ink)
            Text(store.library.open.isEmpty
                 ? "Save a video with Add, or share one to WatchLater from YouTube."
                 : "Try a longer slot, or Everything.")
                .font(Type.body).foregroundStyle(Paper.inkSoft).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
        .accessibilityIdentifier("wl-empty")
    }

    private var addBar: some View {
        HStack {
            Button { sheet = .add } label: {
                HStack(spacing: 10) {
                    PlusMark(size: 20, weight: 3)
                    Text(store.busy ?? "Add").font(.system(size: 17, weight: .semibold))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 22).padding(.vertical, 13)
                .background(Capsule().fill(Paper.accent))
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("wl-add")
        }
        .padding(.horizontal, 16)
    }
}

/// Copies, and shows that it did — a copy that cannot fail silently.
struct CopyButton: View {
    let title: String
    let text: String
    let identifier: String
    @State private var done = false

    var body: some View {
        QuietButton(identifier: identifier) {
            Clipboard.set(text)
            done = true
            Task { try? await Task.sleep(nanoseconds: 1_500_000_000); done = false }
        } label: {
            HStack(spacing: 6) {
                if done { TickMark(size: 15).foregroundStyle(Paper.accent) }
                Text(done ? "Copied" : title)
            }
        }
    }
}

enum Clipboard {
    static func set(_ s: String) {
        #if os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(s, forType: .string)
        #else
        UIPasteboard.general.string = s
        #endif
    }
    static func get() -> String? {
        #if os(macOS)
        return NSPasteboard.general.string(forType: .string)
        #else
        return UIPasteboard.general.string
        #endif
    }
}

/// Pills that wrap onto the next line instead of running off the screen.
struct FlowRow: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 600
        var x: CGFloat = 0, y: CGFloat = 0, rowH: CGFloat = 0
        for s in subviews {
            let sz = s.sizeThatFits(.unspecified)
            if x > 0 && x + sz.width > width { x = 0; y += rowH + spacing; rowH = 0 }
            x += sz.width + spacing
            rowH = max(rowH, sz.height)
        }
        return CGSize(width: width, height: y + rowH)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, rowH: CGFloat = 0
        for s in subviews {
            let sz = s.sizeThatFits(.unspecified)
            if x > bounds.minX && x + sz.width > bounds.maxX { x = bounds.minX; y += rowH + spacing; rowH = 0 }
            s.place(at: CGPoint(x: x, y: y), anchor: .topLeading, proposal: .unspecified)
            x += sz.width + spacing
            rowH = max(rowH, sz.height)
        }
    }
}
