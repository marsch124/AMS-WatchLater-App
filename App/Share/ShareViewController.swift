import UIKit
import SwiftUI
import UniformTypeIdentifiers
import WatchLaterCore

/// Share → WatchLater. Takes the link from the share sheet, writes it straight
/// into the list in iCloud (so the Mac sees it without this phone opening the
/// app), shows a small "Saved" and closes. Without iCloud the link waits in the
/// app group; the app takes it in the next time it opens.
final class ShareViewController: UIViewController {
    static let appGroup = "group.com.schabbauer.AMSWatchLater"
    static let container = "iCloud.com.schabbauer.AMSWatchLater"

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
        loadLink { [weak self] link in
            guard let self else { return }
            guard let link, YouTube.videoId(in: link) != nil || link.hasPrefix("http") else {
                self.show(text: "No link in that", ok: false); return
            }
            let ok = self.save(link)
            self.show(text: ok ? "Saved to WatchLater" : "Could not save", ok: ok)
        }
    }

    private func loadLink(_ done: @escaping (String?) -> Void) {
        let providers = (extensionContext?.inputItems as? [NSExtensionItem])?.flatMap { $0.attachments ?? [] } ?? []
        var found: String?
        let group = DispatchGroup()
        for p in providers {
            if p.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
                group.enter()
                p.loadItem(forTypeIdentifier: UTType.url.identifier) { item, _ in
                    if let u = item as? URL { found = found ?? u.absoluteString }
                    else if let d = item as? Data, let u = URL(dataRepresentation: d, relativeTo: nil) { found = found ?? u.absoluteString }
                    group.leave()
                }
            } else if p.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
                group.enter()
                p.loadItem(forTypeIdentifier: UTType.plainText.identifier) { item, _ in
                    let s = (item as? String) ?? (item as? Data).flatMap { String(data: $0, encoding: .utf8) } ?? ""
                    if let l = YouTube.links(in: s).first { found = found ?? l }
                    group.leave()
                }
            }
        }
        group.notify(queue: .main) { done(found) }
    }

    private var usesICloud: Bool {
        (Bundle.main.object(forInfoDictionaryKey: "WatchLaterUsesICloud") as? String) == "YES"
    }

    private func save(_ link: String) -> Bool {
        let fm = FileManager.default
        if usesICloud, let cloud = fm.url(forUbiquityContainerIdentifier: Self.container) {
            let file = LibraryFile(url: cloud.appendingPathComponent("Documents/watchlater.json"))
            let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
            file.addBare(url: link, version: version)
            return true
        }
        guard let inbox = fm.containerURL(forSecurityApplicationGroupIdentifier: Self.appGroup)?
            .appendingPathComponent("inbox.txt") else { return false }
        let old = (try? String(contentsOf: inbox, encoding: .utf8)) ?? ""
        return (try? (old + link + "\n").write(to: inbox, atomically: true, encoding: .utf8)) != nil
    }

    private func show(text: String, ok: Bool) {
        let host = UIHostingController(rootView: SavedCard(text: text, ok: ok))
        host.view.backgroundColor = .clear
        addChild(host)
        host.view.frame = view.bounds
        host.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(host.view)
        host.didMove(toParent: self)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) { [weak self] in
            self?.extensionContext?.completeRequest(returningItems: nil)
        }
    }
}

private struct SavedCard: View {
    let text: String
    let ok: Bool
    var body: some View {
        VStack {
            Spacer()
            HStack(spacing: 12) {
                Circle().fill(ok ? Color(red: 0.11, green: 0.48, blue: 0.37) : Color(red: 0.72, green: 0.2, blue: 0.18))
                    .frame(width: 14, height: 14)
                Text(text).font(.system(size: 18, weight: .semibold))
            }
            .padding(.horizontal, 26).padding(.vertical, 18)
            .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(.regularMaterial))
            Spacer()
        }
    }
}
