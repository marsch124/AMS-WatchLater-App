import SwiftUI
import WatchLaterCore

@main
struct WatchLaterApp: App {
    @StateObject private var store = Store()
    @Environment(\.scenePhase) private var phase

    #if os(macOS)
    @NSApplicationDelegateAdaptor(MacAppDelegate.self) private var macDelegate
    #endif

    var body: some Scene {
        WindowGroup { root }
        #if os(macOS)
        .defaultSize(width: 980, height: 760)
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

#if os(macOS)
/// A safety net for the one window. Started some ways (a UI test, a fresh
/// build, a remembered "closed" state) the Mac came up with the app running and
/// NO window — and the hidden caption player lives in that window. ⌘N always
/// worked, so when there is no window this does exactly what ⌘N does.
/// (2026-09-28: WindowGroup had no window under the Mac UI tests; a single
/// Window had none when opened from Finder. This covers both.)
final class MacAppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ note: Notification) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { Self.ensureWindow() }
    }

    /// A click on the Dock icon with no window open brings one back.
    func applicationShouldHandleReopen(_ app: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag { Self.ensureWindow() }
        return true
    }

    static func ensureWindow() {
        guard !NSApp.windows.contains(where: { $0.isVisible && $0.canBecomeMain }) else { return }
        let items = NSApp.mainMenu?.items.flatMap { $0.submenu?.items ?? [] } ?? []
        if let newWindow = items.first(where: { $0.keyEquivalent == "n" && $0.keyEquivalentModifierMask == .command }),
           let action = newWindow.action {
            NSApp.sendAction(action, to: newWindow.target, from: newWindow)
        }
    }
}
#endif
