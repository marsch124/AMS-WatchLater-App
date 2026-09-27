import SwiftUI
import WatchLaterCore

/// One video. Picture on top with the length in the corner, then the words,
/// then a quiet row of what you can do to it.
struct CardView: View {
    @EnvironmentObject private var store: Store
    @Environment(\.openURL) private var openURL
    let video: Video
    let picked: Bool
    let togglePick: () -> Void
    let pickChannel: () -> Void
    let pickTag: (String) -> Void

    @State private var editingNote = false
    @State private var noteDraft = ""
    @State private var editingTags = false
    @State private var tagsDraft = ""
    @State private var askingLength = false
    @State private var lengthDraft = ""

    private var stale: Bool { video.isStale() }
    private var edge: Color { video.isPinned ? Paper.accent : (stale ? Paper.amber : Paper.line) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            picture
            VStack(alignment: .leading, spacing: 6) {
                Text(video.title.isEmpty ? video.url : video.title)
                    .font(Type.cardTitle).foregroundStyle(Paper.ink)
                    .lineLimit(3).fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("wl-title-\(video.id)")
                HStack(spacing: 6) {
                    if !video.channel.isEmpty {
                        Button(action: pickChannel) {
                            Text(video.channel).font(Type.small).foregroundStyle(Paper.inkSoft).lineLimit(1)
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("wl-channel-\(video.id)")
                    }
                    if video.goneAt != nil {
                        Text("GONE?").font(.system(size: 15, weight: .bold)).foregroundStyle(Paper.danger)
                    }
                }
                note
                if !video.tags.isEmpty || editingTags { tags }
                Text(Clock.age(of: video)).font(Type.small).foregroundStyle(stale ? Paper.amber : Paper.inkSoft)
                    .accessibilityIdentifier("wl-age-\(video.id)")
                if video.awaitsAnswer { answerRow }
                if stale && !video.awaitsAnswer { staleRow }
                actions
            }
            .padding(12)
        }
        .modifier(CardFrame(tint: edge, width: video.isPinned || stale ? 2 : 1))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("wl-card-\(video.id)")
    }

    // MARK: Picture

    private var picture: some View {
        ZStack(alignment: .bottomTrailing) {
            Button {
                if let u = video.watchURL { openURL(u); store.started(video) }
            } label: {
                ZStack {
                    Rectangle().fill(Paper.shade)
                    if let id = video.videoId, Thumbs.have(id),
                       let img = loadImage(Thumbs.url(for: id)) {
                        img.resizable().aspectRatio(contentMode: .fill)
                    } else {
                        PlayMark(size: 40, weight: 2.5).foregroundStyle(Paper.inkSoft)
                    }
                }
                .frame(height: 150)
                .clipped()
                .contentShape(Rectangle())
                .id(store.thumbTick)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("wl-open-\(video.id)")

            if let badge = Clock.badge(video.seconds) {
                Text(badge).font(Type.badge).foregroundStyle(.white)
                    .padding(.horizontal, 7).padding(.vertical, 3)
                    .background(RoundedRectangle(cornerRadius: 6).fill(Color.black.opacity(0.75)))
                    .padding(8)
                    .accessibilityIdentifier("wl-length-\(video.id)")
            } else {
                Button { lengthDraft = ""; askingLength = true } label: {
                    Text("How long?").font(Type.badge).foregroundStyle(.white)
                        .padding(.horizontal, 7).padding(.vertical, 3)
                        .background(RoundedRectangle(cornerRadius: 6).fill(Paper.amber))
                        .padding(8)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("wl-asklength-\(video.id)")
                .alert("About how long is it?", isPresented: $askingLength) {
                    TextField("Minutes", text: $lengthDraft)
                    Button("Save") { if let m = Int(lengthDraft) { store.setSeconds(video, m * 60) } }
                    Button("Cancel", role: .cancel) {}
                }
            }

            // Corners: pick top-left, pin top-right, together bottom-left.
            VStack {
                HStack {
                    cornerButton(on: picked, mark: { TickMark(size: 14, weight: 2.6) }, id: "wl-pick-\(video.id)", action: togglePick)
                    Spacer()
                    cornerButton(on: video.isPinned, mark: { PinMark(size: 15, filled: video.isPinned) }, id: "wl-pin-\(video.id)") { store.togglePin(video) }
                }
                Spacer()
                HStack {
                    cornerButton(on: video.isTogether, tint: Paper.pair, mark: { PairMark(size: 16, filled: video.isTogether) }, id: "wl-pair-\(video.id)") { store.toggleTogether(video) }
                    Spacer()
                }
            }
            .padding(8)
            .frame(height: 150)

            if video.countsAsShort {
                Text("SHORT").font(.system(size: 15, weight: .bold)).foregroundStyle(.white)
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(RoundedRectangle(cornerRadius: 5).fill(Paper.pair))
                    .padding(8)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .padding(.leading, 34)
                    .allowsHitTesting(false)
            }
        }
        .frame(height: 150)
        .clipShape(UnevenRoundedRectangle(topLeadingRadius: 14, topTrailingRadius: 14))
    }

    private func cornerButton<M: View>(on: Bool, tint: Color = Paper.accent, @ViewBuilder mark: () -> M,
                                       id: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            mark()
                .foregroundStyle(on ? .white : Paper.ink)
                .frame(width: 30, height: 30)
                .background(Circle().fill(on ? tint : Paper.card.opacity(0.92)))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(id)
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

    // MARK: Words he adds

    private var note: some View {
        Group {
            if editingNote {
                TextField("A line in your own words", text: $noteDraft, axis: .vertical)
                    .textFieldStyle(.plain).font(Type.body).foregroundStyle(Paper.ink)
                    .padding(8)
                    .background(RoundedRectangle(cornerRadius: 8).fill(Paper.shade))
                    .onSubmit { store.setNote(video, noteDraft); editingNote = false }
                    .accessibilityIdentifier("wl-note-field-\(video.id)")
                HStack(spacing: 8) {
                    GoButton(title: "Save", identifier: "wl-note-save-\(video.id)") {
                        store.setNote(video, noteDraft); editingNote = false
                    }
                    QuietButton(identifier: "wl-note-cancel-\(video.id)") { editingNote = false } label: { Text("Cancel") }
                }
            } else {
                Button { noteDraft = video.note; editingNote = true } label: {
                    HStack(alignment: .top, spacing: 6) {
                        PencilMark().foregroundStyle(Paper.inkSoft).padding(.top, 2)
                        Text(video.note.isEmpty ? "Add a note" : video.note)
                            .font(Type.body).foregroundStyle(video.note.isEmpty ? Paper.inkSoft.opacity(0.7) : Paper.ink)
                            .multilineTextAlignment(.leading)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("wl-note-\(video.id)")
            }
        }
    }

    private var tags: some View {
        Group {
            if editingTags {
                TextField("Tags, separated by commas", text: $tagsDraft)
                    .textFieldStyle(.plain).font(Type.body).foregroundStyle(Paper.ink)
                    .padding(8).background(RoundedRectangle(cornerRadius: 8).fill(Paper.shade))
                    .onSubmit { saveTags() }
                    .accessibilityIdentifier("wl-tags-field-\(video.id)")
                HStack(spacing: 8) {
                    GoButton(title: "Save", identifier: "wl-tags-save-\(video.id)") { saveTags() }
                    QuietButton(identifier: "wl-tags-cancel-\(video.id)") { editingTags = false } label: { Text("Cancel") }
                }
            } else {
                FlowRow(spacing: 6) {
                    ForEach(video.tags, id: \.self) { t in
                        Button { pickTag(t) } label: {
                            Text(t).font(Type.small).foregroundStyle(Paper.accentInk)
                                .padding(.horizontal, 9).padding(.vertical, 3)
                                .background(Capsule().fill(Paper.accentSoft))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private func saveTags() {
        store.setTags(video, tagsDraft.split(separator: ",").map(String.init))
        editingTags = false
    }

    // MARK: Questions the card asks

    private var answerRow: some View {
        HStack(spacing: 8) {
            Text("Did you finish it?").font(Type.body).foregroundStyle(Paper.ink)
            Spacer()
            GoButton(title: "Yes", identifier: "wl-finished-\(video.id)") { store.answer(video, finished: true) }
            QuietButton(identifier: "wl-notyet-\(video.id)") { store.answer(video, finished: false) } label: { Text("Not yet") }
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 10).fill(Paper.accentSoft))
    }

    private var staleRow: some View {
        HStack(spacing: 8) {
            Text("Three months. Still?").font(Type.body).foregroundStyle(Paper.amber)
            Spacer()
            GoButton(title: "Keep", tint: Paper.amber, identifier: "wl-keep-\(video.id)") { store.keep(video) }
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 10).fill(Paper.amberSoft))
    }

    // MARK: The row

    private var actions: some View {
        HStack(spacing: 8) {
            if video.isOpen {
                Button { store.setWatched(video, true) } label: {
                    HStack(spacing: 6) { TickMark(size: 15); Text("Watched") }
                        .font(Type.pill).foregroundStyle(Paper.accentInk)
                        .padding(.horizontal, 12).padding(.vertical, 8)
                        .background(Capsule().fill(Paper.accentSoft))
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("wl-tick-\(video.id)")
            } else {
                QuietButton(identifier: "wl-untick-\(video.id)") { store.setWatched(video, false) } label: { Text("Back to the list") }
            }
            QuietButton(identifier: "wl-tag-\(video.id)") {
                tagsDraft = video.tags.joined(separator: ", "); editingTags = true
            } label: { TagMark() }
            Spacer()
            // Remove: one red, quiet, last.
            Button { store.bin(video) } label: {
                BinMark(size: 16).foregroundStyle(Paper.danger)
                    .frame(width: 34, height: 34)
                    .background(Circle().strokeBorder(Paper.line))
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("wl-bin-\(video.id)")
        }
        .padding(.top, 4)
    }
}
