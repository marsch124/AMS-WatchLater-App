import SwiftUI
import WatchLaterCore

@main
struct WatchLaterApp: App {
    @StateObject private var store = Store()
    @Environment(\.scenePhase) private var phase

    var body: some Scene {
        #if os(macOS)
        // One list, one window. A WindowGroup started by the UI tests on the
        // Mac made no first window at all (CI, 2026-09-28: the app ran in front
        // with zero windows until ⌘N) — a single Window always opens at launch.
        Window("WatchLater", id: "main") { root }
            .defaultSize(width: 980, height: 760)
        #else
        WindowGroup { root }
        #endif
    }

    private var root: some View {
        MainView()
            .environmentObject(store)
            .onOpenURL { url in handle(url) }
            .onChange(of: phase) { _, now in
                // Coming back to the app is the moment to hear what the
                // other device did, and to take in what the share sheet left.
                if now == .active { store.reload() }
            }
    }

    /// amswatchlater://add?url=… — the door for Raycast and the old Dock button.
    private func handle(_ url: URL) {
        guard url.scheme == "amswatchlater" else { return }
        let parts = URLComponents(url: url, resolvingAgainstBaseURL: false)
        guard let link = parts?.queryItems?.first(where: { $0.name == "url" })?.value, !link.isEmpty else { return }
        Task { store.say(await store.add(text: link).line) }
    }
}
