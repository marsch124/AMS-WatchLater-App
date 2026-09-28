import SwiftUI
import WatchLaterCore

@main
struct WatchLaterApp: App {
    @StateObject private var store = Store()
    @Environment(\.scenePhase) private var phase

    var body: some Scene {
        WindowGroup {
            MainView()
                .environmentObject(store)
                .onOpenURL { url in handle(url) }
                .onChange(of: phase) { _, now in
                    // Coming back to the app is the moment to hear what the
                    // other device did, and to take in what the share sheet left.
                    if now == .active { store.reload() }
                }
        }
        #if os(macOS)
        .defaultSize(width: 980, height: 760)
        #endif
    }

    /// amswatchlater://add?url=… — the door for Raycast and the old Dock button.
    private func handle(_ url: URL) {
        guard url.scheme == "amswatchlater" else { return }
        let parts = URLComponents(url: url, resolvingAgainstBaseURL: false)
        guard let link = parts?.queryItems?.first(where: { $0.name == "url" })?.value, !link.isEmpty else { return }
        Task { store.say(await store.add(text: link).line) }
    }
}
