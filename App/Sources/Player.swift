import SwiftUI
import WebKit

/// YouTube's own embedded player, inside the app — so a mark can ask it what
/// second it is at, and a tap on a mark can jump back to that second. Some
/// videos refuse to be embedded; then the page says so and offers YouTube.
@MainActor
final class PlayerHandle: ObservableObject {
    enum State: Equatable { case loading, ready, refused(Int) }
    @Published var state: State = .loading
    weak var webView: WKWebView?

    /// Whole seconds into the video, or nil while nothing is playing.
    func now() async -> Int? {
        guard state == .ready, let web = webView,
              let v = try? await web.evaluateJavaScript("now()") as? NSNumber else { return nil }
        // 0 means it has not started — a mark then has no time rather than a
        // false "0:00" (seen on the Mac 2026-09-27).
        return v.intValue > 0 ? v.intValue : nil
    }

    func seek(_ seconds: Int) {
        webView?.evaluateJavaScript("seek(\(seconds))", completionHandler: nil)
    }

    func pause() {
        webView?.evaluateJavaScript("pause()", completionHandler: nil)
    }
}

struct YouTubePlayer: View {
    let videoId: String
    var start: Int = 0
    @ObservedObject var handle: PlayerHandle

    var body: some View {
        PlayerWeb(videoId: videoId, start: start, handle: handle)
            .aspectRatio(16 / 9, contentMode: .fit)
            .background(Color.black)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .accessibilityIdentifier("wl-player")
    }

    /// YouTube wants an embedding app to name itself: the page's address (and
    /// so the Referer the player sees) is https://<bundle id>. Pretending to be
    /// youtube.com gets error 152, "video player configuration error" — found on
    /// the Mac 2026-09-27.
    static let origin = "https://com.schabbauer.amswatchlater"

    static func html(videoId: String, start: Int) -> String {
        """
        <!doctype html><html><head>
        <meta name="viewport" content="width=device-width,initial-scale=1,maximum-scale=1">
        <style>html,body{margin:0;height:100%;background:#000;overflow:hidden}#p{position:absolute;inset:0;width:100%;height:100%}</style>
        </head><body><div id="p"></div>
        <script>
        var player;
        function say(m){ try{ window.webkit.messageHandlers.wl.postMessage(m) }catch(e){} }
        function onYouTubeIframeAPIReady(){
          player = new YT.Player('p', {
            videoId: '\(videoId)',
            playerVars: { playsinline: 1, rel: 0, modestbranding: 1, start: \(start),
                          origin: '\(origin)' },
            events: {
              onReady: function(){ say('ready') },
              onError: function(e){ say('error:' + e.data) }
            }
          });
        }
        function now(){ return (player && player.getCurrentTime) ? Math.floor(player.getCurrentTime()) : -1 }
        function seek(s){ if (player && player.seekTo){ player.seekTo(s, true); player.playVideo() } }
        function pause(){ if (player && player.pauseVideo){ player.pauseVideo() } }
        </script>
        <script src="https://www.youtube.com/iframe_api"></script>
        </body></html>
        """
    }
}

final class PlayerCoordinator: NSObject, WKScriptMessageHandler {
    let handle: PlayerHandle
    init(handle: PlayerHandle) { self.handle = handle }

    func userContentController(_ c: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let text = message.body as? String else { return }
        Task { @MainActor in
            if text == "ready" { self.handle.state = .ready }
            else if text.hasPrefix("error:") { self.handle.state = .refused(Int(text.dropFirst(6)) ?? 0) }
        }
    }
}

private func makeWebView(videoId: String, start: Int, coordinator: PlayerCoordinator) -> WKWebView {
    let config = WKWebViewConfiguration()
    config.userContentController.add(coordinator, name: "wl")
    #if os(iOS)
    config.allowsInlineMediaPlayback = true
    #endif
    config.mediaTypesRequiringUserActionForPlayback = []
    let web = WKWebView(frame: .zero, configuration: config)
    #if os(iOS)
    web.scrollView.isScrollEnabled = false
    web.isOpaque = false
    web.backgroundColor = .black
    #endif
    web.loadHTMLString(YouTubePlayer.html(videoId: videoId, start: start),
                       baseURL: URL(string: YouTubePlayer.origin))
    Task { @MainActor in coordinator.handle.webView = web }
    return web
}

#if os(macOS)
private struct PlayerWeb: NSViewRepresentable {
    let videoId: String
    let start: Int
    let handle: PlayerHandle
    func makeCoordinator() -> PlayerCoordinator { PlayerCoordinator(handle: handle) }
    func makeNSView(context: Context) -> WKWebView { makeWebView(videoId: videoId, start: start, coordinator: context.coordinator) }
    func updateNSView(_ v: WKWebView, context: Context) {}
    static func dismantleNSView(_ v: WKWebView, coordinator: PlayerCoordinator) {
        v.configuration.userContentController.removeScriptMessageHandler(forName: "wl")
    }
}
#else
private struct PlayerWeb: UIViewRepresentable {
    let videoId: String
    let start: Int
    let handle: PlayerHandle
    func makeCoordinator() -> PlayerCoordinator { PlayerCoordinator(handle: handle) }
    func makeUIView(context: Context) -> WKWebView { makeWebView(videoId: videoId, start: start, coordinator: context.coordinator) }
    func updateUIView(_ v: WKWebView, context: Context) {}
    static func dismantleUIView(_ v: WKWebView, coordinator: PlayerCoordinator) {
        v.configuration.userContentController.removeScriptMessageHandler(forName: "wl")
    }
}
#endif
