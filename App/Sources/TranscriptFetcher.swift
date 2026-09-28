import SwiftUI
import WebKit
import WatchLaterCore

/// Fetches what was said in each video, one at a time, in a hidden, muted copy
/// of YouTube's own player.
///
/// Why this roundabout way: YouTube answers a caption request from anything but
/// its own player with an empty file, and its transcript endpoint says
/// "precondition failed" (checked 2026-09-28). Its player, though, downloads the
/// whole caption file the moment subtitles are switched on. So the player is
/// asked to switch them on, and a small script inside it catches that file.
@MainActor
final class TranscriptFetcher: NSObject, ObservableObject, WKScriptMessageHandler {
    @Published private(set) var current: String?
    @Published private(set) var waiting = 0

    private let shelf: TranscriptShelf
    private var queue: [String] = []
    private var timeout: Task<Void, Never>?
    private(set) var web: WKWebView?
    var onSaved: ((String) -> Void)?

    /// How long one video may take before it is given up on (and retried in a week).
    static let patience: UInt64 = 40

    init(shelf: TranscriptShelf) {
        self.shelf = shelf
        super.init()
    }

    /// Videos to look at. Ones already on the shelf, or tried recently, are skipped.
    func enqueue(_ videoIds: [String]) {
        log("enqueue \(videoIds.count) — web \(web == nil ? "missing" : "ready")")
        for id in videoIds where shelf.needsFetch(id) && !queue.contains(id) && id != current {
            queue.append(id)
        }
        waiting = queue.count
        startNext()
    }

    func makeWebView() -> WKWebView {
        if let web { return web }
        let config = WKWebViewConfiguration()
        let ucc = config.userContentController
        ucc.add(WeakHandler(self), name: "wlcap")
        // In EVERY frame, from the very start: YouTube's player lives in an
        // iframe, and its caption request has to be seen as it leaves.
        ucc.addUserScript(WKUserScript(source: Self.catcher, injectionTime: .atDocumentStart, forMainFrameOnly: false))
        #if os(iOS)
        config.allowsInlineMediaPlayback = true
        #endif
        config.mediaTypesRequiringUserActionForPlayback = []
        let w = WKWebView(frame: CGRect(x: 0, y: 0, width: 320, height: 180), configuration: config)
        web = w
        // Videos may have been queued before there was a window to play in
        // (seen on the Mac): start them the moment the player has a place.
        DispatchQueue.main.async { [weak self] in self?.startNext() }
        return w
    }

    private func startNext() {
        guard current == nil, let web, !queue.isEmpty else {
            log("startNext skipped: current=\(current ?? "-") web=\(web == nil ? "missing" : "ready") queue=\(queue.count)")
            return
        }
        let id = queue.removeFirst()
        log("asking the player about \(id)")
        waiting = queue.count
        current = id
        web.loadHTMLString(Self.page(videoId: id), baseURL: URL(string: YouTubePlayer.origin))
        timeout?.cancel()
        timeout = Task { [weak self] in
            try? await Task.sleep(nanoseconds: Self.patience * 1_000_000_000)
            guard !Task.isCancelled else { return }
            self?.finish(id, lines: nil)
        }
    }

    private func finish(_ id: String, lines: [Transcript.Line]?) {
        guard current == id else { return }
        log("finished \(id): \(lines?.count ?? 0) lines")
        timeout?.cancel()
        if let lines, !lines.isEmpty {
            shelf.write(Transcript(videoId: id, lines: lines))
            onSaved?(id)
        } else {
            shelf.markNone(id)
        }
        current = nil
        web?.loadHTMLString("<html></html>", baseURL: nil)   // stop the player
        startNext()
    }

    nonisolated func userContentController(_ c: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let body = message.body as? [String: Any], let kind = body["kind"] as? String else { return }
        let size = (body["body"] as? String)?.count ?? 0
        Task { @MainActor in self.log("message \(kind) (\(size) chars)") }
        let text = body["body"] as? String
        Task { @MainActor in
            guard let id = self.current else { return }
            switch kind {
            case "captions":
                let lines = Transcript.parse(Data((text ?? "").utf8))
                if !lines.isEmpty { self.finish(id, lines: lines) }
            case "none", "error":
                self.finish(id, lines: nil)
            default: break
            }
        }
    }

    /// One line per step, to the console — how the Mac problem was found.
    private func log(_ s: String) {
        #if DEBUG
        NSLog("WLCAP %@", s)
        #endif
    }

    /// Runs inside every frame: hands any caption file the player downloads to the app.
    static let catcher = """
    (function(){
      if (window.__wlcap) return; window.__wlcap = true;
      function post(m){ try { window.webkit.messageHandlers.wlcap.postMessage(m); } catch(e){} }
      function grab(u, t){ if (String(u).indexOf('/api/timedtext') >= 0 && t && t.length > 40) post({kind:'captions', body:t}); }
      var oo = XMLHttpRequest.prototype.open, os = XMLHttpRequest.prototype.send;
      XMLHttpRequest.prototype.open = function(m, u){ this.__wlu = u; return oo.apply(this, arguments); };
      XMLHttpRequest.prototype.send = function(){ var x = this; this.addEventListener('load', function(){ try { grab(x.__wlu, x.responseText); } catch(e){} }); return os.apply(this, arguments); };
      if (window.fetch) { var of = window.fetch; window.fetch = function(i, o){ var p = of.apply(this, arguments); try { var u = String((i && i.url) || i); if (u.indexOf('/api/timedtext') >= 0) p.then(function(r){ r.clone().text().then(function(t){ grab(u, t); }); }); } catch(e){} return p; }; }
    })();
    """

    /// The hidden page: the player, muted, told to play and to switch subtitles on.
    static func page(videoId: String) -> String {
        """
        <!doctype html><html><head><meta name="viewport" content="width=device-width"></head><body style="margin:0">
        <div id="p"></div>
        <script>
        function post(m){ try{ window.webkit.messageHandlers.wlcap.postMessage(m) }catch(e){} }
        var player, tries = 0;
        function onYouTubeIframeAPIReady(){
          player = new YT.Player('p', { width: 320, height: 180, videoId: '\(videoId)',
            playerVars: { autoplay: 1, mute: 1, playsinline: 1, cc_load_policy: 1, rel: 0, origin: '\(YouTubePlayer.origin)' },
            events: {
              onReady: function(e){ e.target.mute(); e.target.playVideo(); },
              onStateChange: function(e){ if (e.data === 1) switchOn(); },
              onError: function(e){ post({kind:'error', body: String(e.data)}); }
            } });
        }
        function switchOn(){
          try { player.loadModule('captions'); } catch(e){}
          setTimeout(function pick(){
            var list = []; try { list = player.getOption('captions', 'tracklist') || []; } catch(e){}
            if (list.length) { try { player.setOption('captions', 'track', list[0]); } catch(e){} }
            else if (++tries < 8) { setTimeout(pick, 1000); }
            else { post({kind:'none'}); }
          }, 1200);
        }
        </script>
        <script src="https://www.youtube.com/iframe_api"></script>
        </body></html>
        """
    }
}

/// WKUserContentController keeps its handlers strongly; this breaks the cycle.
private final class WeakHandler: NSObject, WKScriptMessageHandler {
    weak var target: WKScriptMessageHandler?
    init(_ t: WKScriptMessageHandler) { target = t }
    func userContentController(_ c: WKUserContentController, didReceive m: WKScriptMessage) {
        target?.userContentController(c, didReceive: m)
    }
}

/// Where the hidden player lives: a tiny, invisible corner of the window. (A
/// web view that is not in a window at all will not play, so it needs a place.)
struct TranscriptHost: View {
    @ObservedObject var fetcher: TranscriptFetcher
    var body: some View {
        HostedWeb(web: fetcher.makeWebView())
            .frame(width: 2, height: 2)
            .opacity(0.01)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}

#if os(macOS)
private struct HostedWeb: NSViewRepresentable {
    let web: WKWebView
    func makeNSView(context: Context) -> WKWebView { web }
    func updateNSView(_ v: WKWebView, context: Context) {}
}
#else
private struct HostedWeb: UIViewRepresentable {
    let web: WKWebView
    func makeUIView(context: Context) -> WKWebView { web }
    func updateUIView(_ v: WKWebView, context: Context) {}
}
#endif
