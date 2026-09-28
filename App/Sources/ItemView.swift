import SwiftUI
import WatchLaterCore

/// One saved thing, opened: watch it (or open it), mark what matters, write
/// about it. Everything he writes here is what makes the list a knowledge base.
struct ItemView: View {
    @EnvironmentObject private var store: Store
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Environment(\.theme) private var theme
    let itemID: String
    /// Where the video starts — a "said at" result in Find opens it right there.
    var start: Int? = nil
    /// Set when this card was reached from another one: goes back to it.
    var back: (() -> Void)? = nil
    /// Opens a connected card in the same page.
    var open: ((String) -> Void)? = nil

    @StateObject private var player = PlayerHandle()
    @State private var saidOpen = false
    @State private var saidQuery = ""
    @State private var markTime = ""
    @State private var markText = ""
    @State private var markMissing: String?
    @State private var editingMark: String?
    @State private var editDraft = ""
    @State private var body_ = ""
    @State private var bodyLoaded = false
    @State private var saveWork: Task<Void, Never>?
    @State private var tagsDraft = ""
    @State private var editingTags = false
    @State private var picking = false
    @State private var shownAnswers: Set<Int> = []
    @FocusState private var focus: Field?

    enum Field { case time, text, body, tags }

    private var item: Video? { store.current(itemID) }

    var body: some View {
        ZStack {
            TabBackground()
            if let v = item {
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        topBar(v)
                        media(v)
                        heading(v)
                        composer(v)
                        marks(v)
                        said(v)
                        learn(v)
                        notes(v)
                        connected(v)
                        tagRow(v)
                        doneRow(v)
                    }
                    .padding(20)
                    .padding(.bottom, 40)
                }
                .scrollDismissesKeyboard(.interactively)
            }
        }
        #if os(macOS)
        .frame(minWidth: 640, idealWidth: 760, minHeight: 640, idealHeight: 860)
        #endif
        .onAppear {
            guard let v = item, !bodyLoaded else { return }
            body_ = v.body
            bodyLoaded = true
            if v.kind.isTimed { store.started(v) }
        }
        .sheet(isPresented: $picking) {
            if let v = item {
                LinkPicker(from: v) { other in store.link(v.id, to: other); picking = false }
                    .environmentObject(store)
                    .environment(\.theme, theme)
            }
        }
        .onDisappear {
            saveWork?.cancel()
            store.setBody(itemID, body_)
            player.pause()
        }
    }

    // MARK: Top

    private func topBar(_ v: Video) -> some View {
        HStack(spacing: 10) {
            if let back {
                Button(action: back) {
                    BackMark(size: 16).foregroundStyle(Paper.ink)
                        .frame(width: 38, height: 38)
                        .background(Circle().fill(Paper.card).overlay(Circle().strokeBorder(Paper.line)))
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("wl-item-back")
            }
            Text(v.kind.title.dropLast().uppercased())
                .font(.system(size: 15, weight: .bold)).tracking(0.8).foregroundStyle(Paper.accent)
            Spacer()
            Button { dismiss() } label: {
                CrossMark(size: 18).foregroundStyle(Paper.ink)
                    .frame(width: 38, height: 38)
                    .background(Circle().fill(Paper.card).overlay(Circle().strokeBorder(Paper.line)))
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("wl-item-close")
        }
    }

    @ViewBuilder
    private func media(_ v: Video) -> some View {
        if v.kind == .video, let id = v.videoId, !store.offline {
            switch player.state {
            case .refused(let code):
                VStack(alignment: .leading, spacing: 10) {
                    picture(v)
                    Text("This video only plays on YouTube. Marks still work — type the time. (YouTube's reason: \(code))")
                        .font(Type.body).foregroundStyle(Paper.inkSoft)
                        .accessibilityIdentifier("wl-player-refused")
                }
            default:
                YouTubePlayer(videoId: id, start: start ?? 0, handle: player)
            }
        } else if v.kind.isTimed || Thumbs.have(v.thumbKey) {
            picture(v)
        }
        // A page with no picture of its own shows none — an empty box is noise.
    }

    private func picture(_ v: Video) -> some View {
        ZStack {
            Rectangle().fill(Paper.shade)
            if Thumbs.have(v.thumbKey), let img = loadImage(Thumbs.url(for: v.thumbKey)) {
                img.resizable().aspectRatio(contentMode: .fill)
            } else {
                KindMark(kind: v.kind, size: 44, weight: 3).foregroundStyle(Paper.inkSoft)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 200)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func heading(_ v: Video) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(v.title.isEmpty ? v.url : v.title)
                .font(.system(size: 24, weight: .heavy, design: .rounded)).foregroundStyle(Paper.accentInk)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("wl-item-title")
            Text(metaLine(v)).font(Type.body).foregroundStyle(Paper.inkSoft)
            if !v.blurb.isEmpty {
                Text(v.blurb).font(Type.body).foregroundStyle(Paper.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let u = v.watchURL {
                QuietButton(identifier: "wl-item-open") { openURL(u) } label: {
                    Text(openWord(v))
                }
            }
        }
    }

    private func metaLine(_ v: Video) -> String {
        var parts: [String] = []
        if !v.channel.isEmpty { parts.append(v.channel) }
        if let s = v.seconds {
            parts.append(v.kind.isTimed ? (Clock.badge(s) ?? "") : "\(max(1, s / 60)) min read")
        }
        parts.append(Clock.age(of: v, now: Date()))
        return parts.joined(separator: " · ")
    }

    private func openWord(_ v: Video) -> String {
        switch v.kind {
        case .video:   return v.videoId != nil ? "Open in YouTube" : "Open the video"
        case .podcast: return "Open the episode"
        case .article: return "Open the article"
        case .page:    return "Open the page"
        }
    }

    // MARK: Marking

    private func composer(_ v: Video) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(v.kind.isTimed ? "Mark a moment" : "Keep a quote or a thought")
                .font(.system(size: 17, weight: .bold)).foregroundStyle(Paper.accentInk)
            HStack(spacing: 8) {
                if v.kind.isTimed {
                    TextField("12:34", text: $markTime)
                        .textFieldStyle(.plain).font(Type.badge).foregroundStyle(Paper.ink)
                        .frame(width: 76)
                        .padding(10)
                        .background(RoundedRectangle(cornerRadius: 10).fill(Paper.card)
                            .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Paper.line)))
                        .focused($focus, equals: .time)
                        .accessibilityIdentifier("wl-mark-time")
                }
                // One line, so Return means "mark it" — on the phone the keyboard
                // covers the Mark button (CI's iPhone found that), and Return is
                // where the thumb already is.
                TextField(v.kind.isTimed ? "What is worth keeping here?" : "A quote, or what you think",
                          text: $markText)
                    .textFieldStyle(.plain).font(Type.body).foregroundStyle(Paper.ink)
                    .submitLabel(.done)
                    .padding(10)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Paper.card)
                        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Paper.line)))
                    .focused($focus, equals: .text)
                    .onSubmit { Task { await addMark(v) } }
                    .accessibilityIdentifier("wl-mark-text")
            }
            HStack(spacing: 10) {
                GoButton(title: v.kind.isTimed ? "Mark" : "Keep", identifier: "wl-mark-add") {
                    Task { await addMark(v) }
                }
                if v.kind.isTimed {
                    Text(player.state == .ready ? "Empty time = the second the video is at"
                                                : "Type the time, like 12:34 or 12")
                        // On the phone the keyboard covers this button; its ✓ key marks too.
                        .font(Type.small).foregroundStyle(Paper.inkSoft)
                }
            }
            if let markMissing {
                Text(markMissing).font(Type.body).foregroundStyle(Paper.amber)
                    .accessibilityIdentifier("wl-mark-missing")
            }
        }
        .padding(14)
        .modifier(CardFrame())
    }

    private func addMark(_ v: Video) async {
        var seconds: Int? = nil
        if v.kind.isTimed {
            if !markTime.trimmingCharacters(in: .whitespaces).isEmpty {
                guard let s = Clock.parseMoment(markTime) else {
                    markMissing = "That time is not one I can read — try 12:34, or 12 for twelve minutes."
                    return
                }
                seconds = s
            } else {
                seconds = await player.now()
            }
        }
        let text = markText.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.isEmpty && seconds == nil {
            markMissing = v.kind.isTimed
                ? "Write what is worth keeping, or give a time."
                : "Write the quote or the thought first."
            return
        }
        store.addMark(to: v.id, seconds: seconds, text: text)
        markText = ""
        markTime = ""
        markMissing = nil
        focus = .text
    }

    @ViewBuilder
    private func marks(_ v: Video) -> some View {
        let list = v.sortedMarks
        if !list.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text(v.kind.isTimed ? "Marks · \(list.count)" : "Kept · \(list.count)")
                    .font(.system(size: 17, weight: .bold)).foregroundStyle(Paper.accentInk)
                ForEach(Array(list.enumerated()), id: \.element.id) { i, m in
                    markRow(v, m, index: i)
                }
            }
        }
    }

    private func markRow(_ v: Video, _ m: Mark, index i: Int) -> some View {
        HStack(alignment: .top, spacing: 10) {
            if let s = m.seconds, let badge = Clock.badge(s) {
                Button { jump(v, to: s) } label: {
                    HStack(spacing: 5) {
                        PlayMark(size: 14, weight: 1.6)
                        Text(badge).font(Type.badge)
                    }
                    .foregroundStyle(Paper.accentInk)
                    .padding(.horizontal, 9).padding(.vertical, 6)
                    .background(Capsule().fill(Paper.accentSoft))
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("wl-mark-jump-\(i)")
            } else {
                Rectangle().fill(Paper.accent).frame(width: 3).padding(.vertical, 2)
            }
            if editingMark == m.id {
                TextField("", text: $editDraft, axis: .vertical)
                    .textFieldStyle(.plain).font(Type.body).foregroundStyle(Paper.ink)
                    .onSubmit { saveEdit(v, m) }
                    .accessibilityIdentifier("wl-mark-edit-\(i)")
                GoButton(title: "Save", identifier: "wl-mark-save-\(i)") { saveEdit(v, m) }
            } else {
                Button { editDraft = m.text; editingMark = m.id } label: {
                    Text(m.text.isEmpty ? "(no words)" : m.text)
                        .font(Type.body).foregroundStyle(m.text.isEmpty ? Paper.inkSoft : Paper.ink)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("wl-mark-row-\(i)")
            }
            // Remove: one red, quiet, last.
            Button { store.removeMark(from: v.id, m) } label: {
                BinMark(size: 15).foregroundStyle(Paper.danger)
                    .frame(width: 32, height: 32)
                    .background(Circle().strokeBorder(Paper.line))
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("wl-mark-remove-\(i)")
        }
        .padding(12)
        .modifier(CardFrame())
    }

    private func saveEdit(_ v: Video, _ m: Mark) {
        var changed = m
        changed.text = editDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        store.updateMark(in: v.id, changed)
        editingMark = nil
    }

    /// In the player when it is here; otherwise YouTube opens at that second.
    private func jump(_ v: Video, to seconds: Int) {
        if player.state == .ready { player.seek(seconds) }
        else if let u = v.url(at: seconds) { openURL(u) }
    }

    // MARK: What was said

    @ViewBuilder
    private func said(_ v: Video) -> some View {
        if let id = v.videoId, let t = store.transcripts[id] {
            VStack(alignment: .leading, spacing: 10) {
                Button { withAnimation(.easeOut(duration: 0.2)) { saidOpen.toggle() } } label: {
                    HStack(spacing: 8) {
                        Text("What was said").font(.system(size: 17, weight: .bold)).foregroundStyle(Paper.accentInk)
                        Text("\(t.lines.count) lines").font(Type.small).foregroundStyle(Paper.inkSoft)
                        Spacer()
                        Text(saidOpen ? "Hide" : "Show").font(Type.pill).foregroundStyle(Paper.accent)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("wl-said-toggle")
                if saidOpen { saidList(v, t) }
            }
        }
    }

    private func saidList(_ v: Video, _ t: Transcript) -> some View {
        let shown = saidQuery.trimmingCharacters(in: .whitespaces).count >= 2 ? t.lines(matching: saidQuery) : t.lines
        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Glyph(art: GlyphArt.find, size: 18).foregroundStyle(Paper.accent)
                TextField("Find in what was said", text: $saidQuery)
                    .textFieldStyle(.plain).font(Type.body).foregroundStyle(Paper.ink)
                    .accessibilityIdentifier("wl-said-find")
            }
            .padding(10)
            .background(RoundedRectangle(cornerRadius: 10).fill(Paper.card)
                .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Paper.line)))
            Text("Tap a time to go there. Keep turns a line into one of your marks.")
                .font(Type.small).foregroundStyle(Paper.inkSoft)
            LazyVStack(alignment: .leading, spacing: 6) {
                ForEach(Array(shown.prefix(600).enumerated()), id: \.offset) { i, line in
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        Button { jump(v, to: line.seconds) } label: {
                            Text(Clock.badge(line.seconds) ?? "0:00")
                                .font(.system(size: 15, weight: .semibold, design: .monospaced))
                                .foregroundStyle(Paper.accentInk)
                                .frame(minWidth: 58, alignment: .leading)
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("wl-said-jump-\(i)")
                        Text(line.s).font(Type.body).foregroundStyle(Paper.ink)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Button { store.addMark(to: v.id, seconds: line.seconds, text: line.s); store.say("Kept as a mark") } label: {
                            Text("Keep").font(.system(size: 15, weight: .semibold)).foregroundStyle(Paper.accent)
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("wl-said-keep-\(i)")
                    }
                    .padding(.vertical, 3)
                }
            }
            .padding(12)
            .modifier(CardFrame())
        }
    }

    // MARK: Learn

    /// Summary, key points and questions — made on the device from what was
    /// said — and a way to find more on the same thing.
    private func learn(_ v: Video) -> some View {
        let said = v.videoId.flatMap { store.transcripts[$0] }
        let working = store.digesting[v.id]
        return VStack(alignment: .leading, spacing: 10) {
            Text("Learn").font(.system(size: 17, weight: .bold)).foregroundStyle(Paper.accentInk)
            if let d = v.digest {
                Text(d.summary).font(Type.body).foregroundStyle(Paper.ink)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("wl-learn-summary")
                if !d.points.isEmpty {
                    Text("Key points").font(.system(size: 15, weight: .semibold)).foregroundStyle(Paper.accentInk)
                    ForEach(Array(d.points.enumerated()), id: \.offset) { _, p in
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Circle().fill(Paper.accent).frame(width: 7, height: 7).offset(y: -2)
                            Text(p).font(Type.body).foregroundStyle(Paper.ink)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                if !d.questions.isEmpty {
                    Text("Check yourself").font(.system(size: 15, weight: .semibold)).foregroundStyle(Paper.accentInk)
                        .padding(.top, 2)
                    ForEach(Array(d.questions.enumerated()), id: \.offset) { i, q in
                        Button {
                            withAnimation(.easeOut(duration: 0.2)) {
                                if shownAnswers.contains(i) { shownAnswers.remove(i) } else { shownAnswers.insert(i) }
                            }
                        } label: {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(q.question).font(.system(size: 16, weight: .semibold)).foregroundStyle(Paper.ink)
                                    .multilineTextAlignment(.leading)
                                if shownAnswers.contains(i) {
                                    Text(q.answer).font(Type.body).foregroundStyle(Paper.accentInk)
                                        .multilineTextAlignment(.leading)
                                        .accessibilityIdentifier("wl-learn-a-\(i)")
                                } else {
                                    Text("Tap to see the answer").font(Type.small).foregroundStyle(Paper.inkSoft)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(12)
                            .modifier(CardFrame())
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("wl-learn-q-\(i)")
                    }
                }
                Text("Made by Apple Intelligence on your device, \(Clock.relative(d.madeAt)). It can get things wrong.")
                    .font(Type.small).foregroundStyle(Paper.inkSoft)
            } else if said != nil || v.kind == .video {
                // The main button is always full colour; pressed too early, it
                // says what is missing underneath.
                GoButton(title: working == nil ? "Summarise" : "Working…", identifier: "wl-learn-go") {
                    store.makeDigest(v)
                }
                if let working {
                    Text(working).font(Type.small).foregroundStyle(Paper.inkSoft)
                        .accessibilityIdentifier("wl-learn-working")
                } else if let why = store.digestTrouble[v.id] {
                    Text(why).font(Type.body).foregroundStyle(Paper.amber)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("wl-learn-why")
                } else {
                    Text("A short summary, the key points and a few questions to check yourself — made on this device from what was said.")
                        .font(Type.small).foregroundStyle(Paper.inkSoft)
                }
            }
            HStack(spacing: 10) {
                if v.digest != nil {
                    QuietButton(identifier: "wl-learn-again") { store.makeDigest(v) } label: {
                        Text(working == nil ? "Summarise again" : "Working…")
                    }
                }
                QuietButton(identifier: "wl-learn-more") {
                    if let u = Research.youTube(Research.query(for: v)) { openURL(u) }
                } label: {
                    HStack(spacing: 6) { Glyph(art: GlyphArt.find, size: 16).foregroundStyle(Paper.accent); Text("Find more on YouTube") }
                }
            }
            if v.digest != nil, working == nil, let why = store.digestTrouble[v.id] {
                Text(why).font(Type.body).foregroundStyle(Paper.amber)
            }
        }
    }

    // MARK: The long note

    private func notes(_ v: Video) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Notes").font(.system(size: 17, weight: .bold)).foregroundStyle(Paper.accentInk)
            ZStack(alignment: .topLeading) {
                if body_.isEmpty {
                    Text("Anything you want to remember — what it taught you, what to try, what it reminds you of. Headings with #, lists with -.")
                        .font(Type.body).foregroundStyle(Paper.inkSoft.opacity(0.8))
                        .padding(.horizontal, 5).padding(.vertical, 8)
                        .allowsHitTesting(false)
                }
                TextEditor(text: $body_)
                    .font(Type.body).foregroundStyle(Paper.ink)
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 180)
                    .focused($focus, equals: .body)
                    .accessibilityIdentifier("wl-item-body")
                    .onChange(of: body_) { _, now in
                        saveWork?.cancel()
                        saveWork = Task {
                            try? await Task.sleep(nanoseconds: 1_200_000_000)
                            guard !Task.isCancelled else { return }
                            store.setBody(itemID, now)
                        }
                    }
            }
            .padding(10)
            .background(RoundedRectangle(cornerRadius: 12).fill(Paper.card)
                .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Paper.line)))
            if ObsidianShelf.folderName != nil {
                QuietButton(identifier: "wl-item-obsidian") {
                    store.setBody(itemID, body_)
                    if let now = store.current(itemID) { store.exportToObsidian(only: now) }
                } label: {
                    HStack(spacing: 6) { Glyph(art: GlyphArt.exportOut, size: 16).foregroundStyle(Paper.accent); Text("Send to Obsidian") }
                }
            }
        }
    }

    // MARK: Connected

    private func connected(_ v: Video) -> some View {
        let links = Connections.all(v, in: store.library)
        let related = Connections.related(to: v, in: store.library)
        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Text(links.isEmpty ? "Connected" : "Connected · \(links.count)")
                    .font(.system(size: 17, weight: .bold)).foregroundStyle(Paper.accentInk)
                Spacer()
                QuietButton(identifier: "wl-link-add") { picking = true } label: {
                    HStack(spacing: 6) { LinkMark(size: 17).foregroundStyle(Paper.accent); Text("Link to…") }
                }
            }
            if links.isEmpty {
                Text("Link this to another card, or write [[its title]] in the note. The other card links back by itself.")
                    .font(Type.small).foregroundStyle(Paper.inkSoft)
            }
            ForEach(links) { l in
                HStack(spacing: 10) {
                    Button { open?(l.item.id) } label: {
                        HStack(spacing: 10) {
                            Text(l.way == .to ? "→" : l.way == .from ? "←" : "↔")
                                .font(.system(size: 17, weight: .bold)).foregroundStyle(Paper.accent)
                                .frame(width: 20)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(l.item.title.isEmpty ? l.item.url : l.item.title)
                                    .font(.system(size: 16, weight: .semibold)).foregroundStyle(Paper.ink)
                                    .lineLimit(2).multilineTextAlignment(.leading)
                                Text(l.item.isOpen ? "Waiting" : "In the Library")
                                    .font(Type.small).foregroundStyle(Paper.inkSoft)
                            }
                            Spacer(minLength: 4)
                            Text("›").font(.system(size: 20, weight: .semibold)).foregroundStyle(Paper.accent)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("wl-conn-\(l.item.id)")
                    // Remove: one red, quiet, last — only for a link made here.
                    if l.made {
                        Button { store.unlink(v.id, l.item.id) } label: {
                            CrossMark(size: 13).foregroundStyle(Paper.danger)
                                .frame(width: 32, height: 32)
                                .background(Circle().strokeBorder(Paper.line))
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("wl-link-remove-\(l.item.id)")
                    }
                }
                .padding(12)
                .modifier(CardFrame())
            }
            if !related.isEmpty {
                Text("Maybe related").font(.system(size: 15, weight: .semibold)).foregroundStyle(Paper.inkSoft)
                    .padding(.top, 4)
                ForEach(related) { x in
                    HStack(spacing: 10) {
                        Button { open?(x.id) } label: {
                            Text(x.title.isEmpty ? x.url : x.title)
                                .font(Type.body).foregroundStyle(Paper.ink)
                                .lineLimit(2).multilineTextAlignment(.leading)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("wl-related-\(x.id)")
                        QuietButton(identifier: "wl-related-link-\(x.id)") { store.link(v.id, to: x.id) } label: {
                            HStack(spacing: 5) { LinkMark(size: 15).foregroundStyle(Paper.accent); Text("Link") }
                        }
                    }
                }
            }
        }
    }

    // MARK: Tags and done

    private func tagRow(_ v: Video) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Tags").font(.system(size: 17, weight: .bold)).foregroundStyle(Paper.accentInk)
            if editingTags {
                TextField("Tags, separated by commas", text: $tagsDraft)
                    .textFieldStyle(.plain).font(Type.body).foregroundStyle(Paper.ink)
                    .padding(10)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Paper.card)
                        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Paper.line)))
                    .focused($focus, equals: .tags)
                    .onSubmit { saveTags(v) }
                    .accessibilityIdentifier("wl-item-tags-field")
                GoButton(title: "Save tags", identifier: "wl-item-tags-save") { saveTags(v) }
            } else {
                FlowRow(spacing: 6) {
                    ForEach(v.tags, id: \.self) { t in
                        Text(t).font(Type.small).foregroundStyle(Paper.accentInk)
                            .padding(.horizontal, 10).padding(.vertical, 5)
                            .background(Capsule().fill(Paper.accentSoft))
                    }
                    QuietButton(identifier: "wl-item-tags") {
                        tagsDraft = v.tags.joined(separator: ", "); editingTags = true; focus = .tags
                    } label: {
                        HStack(spacing: 6) { TagMark(); Text(v.tags.isEmpty ? "Add tags" : "Change") }
                    }
                }
            }
        }
    }

    private func saveTags(_ v: Video) {
        store.setTags(v, tagsDraft.split(separator: ",").map(String.init))
        editingTags = false
    }

    private func doneRow(_ v: Video) -> some View {
        HStack(spacing: 10) {
            if v.isOpen {
                GoButton(title: "\(v.doneWord) — into the Library", identifier: "wl-item-done") {
                    store.setBody(itemID, body_)
                    store.setWatched(v, true)
                    dismiss()
                }
            } else {
                Text("In the Library since \(Clock.relative(v.watchedAt ?? Date()))")
                    .font(Type.body).foregroundStyle(Paper.inkSoft)
                QuietButton(identifier: "wl-item-undone") { store.setWatched(v, false) } label: {
                    Text("Back to the list")
                }
            }
        }
        .padding(.top, 6)
    }

    private func loadImage(_ url: URL) -> Image? {
        #if os(macOS)
        guard let n = NSImage(contentsOf: url) else { return nil }
        return Image(nsImage: n)
        #else
        guard let d = try? Data(contentsOf: url), let u = UIImage(data: d) else { return nil }
        return Image(uiImage: u)
        #endif
    }
}
