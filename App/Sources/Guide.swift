import Foundation

/// The app's own story: what changed, and how it works. One list, read by the
/// version pill and by the guide, so they can never disagree.
struct Release: Identifiable {
    var id: String { version }
    let version: String
    let date: String
    let headline: String
    let lines: [String]
}

enum Guide {

    /// The version the app shows itself — set in project.yml, read from the
    /// bundle, so TestFlight and the pill always agree.
    static var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
    }

    static var build: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? ""
    }

    /// Newest first. Every release adds an entry — never edits an old one.
    static let releases: [Release] = [
        Release(version: "0.3", date: "2026-09-28",
                headline: "Five tabs, each in its own colour",
                lines: [
                    "The app has a tab bar now, the way AMS Instructions does: Watch, Library, Topics, Find and Settings.",
                    "Every tab has its own colour — green, ochre, purple, blue, slate — and everything on it wears that colour: the heading, the section titles, the buttons and pills, even the page of a card you open from there. You can always tell where you are.",
                    "Watch is the list, by the time you have. Library is what you have watched or read, grouped by when, with your marks and notes.",
                    "Topics collects things by subject: every tag you give a card becomes a topic, showing what is still waiting and what is already in the Library.",
                    "Find searches everything at once — titles, channels, tags, your marks and your notes, in the list and the Library — and shows where it found the words, with a mark's time.",
                    "Settings holds your data, import and backup, how to save from the phone, How it works and What's new.",
                ]),
        Release(version: "0.2", date: "2026-09-28",
                headline: "Notes while watching — and anything with a link",
                lines: [
                    "Tap a card's picture or title and it opens its own page. Videos play right there, so you can write while you watch.",
                    "Mark a moment: write what is worth keeping and press Mark — it remembers the second the video is at. Tap the time later and the video jumps back to it. (Or type a time yourself: 12:34, or just 12 for twelve minutes.)",
                    "Every card has a Notes page of its own for anything longer — what it taught you, what to try. It saves as you type.",
                    "Articles, podcasts and web pages can now be saved too, from the share sheet or Add. The app reads their title, site, picture and summary, and works out how long an article takes to read, so it fits the 5 / 20 / 60 minute slots like a video does.",
                    "Watched becomes the Library: what you have watched or read moves there with its marks and notes, instead of disappearing.",
                    "Search now also looks inside your notes and your marks.",
                ]),
        Release(version: "0.1", date: "2026-09-27",
                headline: "The list, now native — on the Mac and on the phone",
                lines: [
                    "The same list on both devices, through iCloud. Save a video on the phone and it is on the Mac when you sit down; tick it off on the Mac and the phone knows.",
                    "On the phone, saving is Share → WatchLater, straight from YouTube (tap More first — YouTube's own share panel hides the share sheet). No shortcut, no folder.",
                    "On the Mac, one button asks Safari for the page you are looking at. Pasting a window of links still works, and so does a whole playlist.",
                    "Everything the web app did is here: I have 5 min / 20 min / an hour, notes, tags, pin, Together and its one-link playlist, Plan an evening, Shorts kept apart, the three-month nudge, and Undo on tick and bin.",
                    "Your data: Import brings the old app's watchlater.json in; Back up now writes a copy wherever you choose.",
                ]),
    ]

    /// Settings › Save from the phone. Every word checked against the real
    /// share sheet — YouTube's own panel hides the system one behind More.
    static let shareSteps: [String] = [
        "In YouTube, tap Share under the video.",
        "YouTube shows its own row of apps first. Scroll it to the end and tap More.",
        "Tap WatchLater. The video is on your list — on the Mac too — before you are back in YouTube.",
        "The first time, WatchLater may be missing from the row: tap More at the end of the app row, switch WatchLater on, and it stays.",
        "Safari and other apps: Share, then WatchLater. Articles and any page work the same way.",
    ]

    static let howItWorks: [(String, String)] = [
        ("What it is for",
         "A list of things you mean to watch or read — YouTube videos, articles, podcasts, any page — sorted by the time you have, not by the date you saved them. Choose 5 min, 20 min or An hour and only what fits is shown. What you have been through moves to the Library, with everything you wrote about it."),
        ("Getting around",
         "Five tabs along the bottom, each with its own colour. Watch (green) is the list of what is waiting. Library (ochre) is what you have watched or read. Topics (purple) gathers things by tag. Find (blue) searches everything. Settings (slate) is your data and this guide. A card you open keeps the colour of the tab you opened it from."),
        ("Library",
         "Tick Watched or Read and a card moves here, keeping its marks and notes. It is grouped into this week, this month and earlier; With notes shows only the cards you wrote something about. Back to the list returns a card to Watch."),
        ("Topics",
         "Give a card a tag (on its page, or with the tag button on the card) and the tag becomes a topic. A topic shows what is still waiting and what is already in the Library. Linking notes to each other comes in a later version."),
        ("Find",
         "Type two letters or more. Find looks in titles, channels, tags, your marks and your notes, and ignores accents. Each result says where it found the words — a mark shows its time. Tap a result to open it."),
        ("A card's own page",
         "Tap a card's picture or title. A video plays right on the page (a few videos only play on YouTube; then there is a button for that). Under it you can mark moments, write notes and set tags."),
        ("Marks",
         "Write what is worth keeping and press Mark — or the ✓ key on the phone's keyboard. With the video playing and the time box empty, the mark takes the second the video is at; or type a time — 12:34, or 12 for twelve minutes. Tap a mark's time to jump back there. On an article a mark is a quote or a thought. Tap a mark's words to change them; the red bin removes it, and Undo brings it back."),
        ("Notes",
         "Each card has room for a longer note. Write in plain text; # makes a heading and - a list, which is how it will look when it goes to Obsidian later. It saves by itself while you type."),
        ("Articles, podcasts, pages",
         "Share any page to WatchLater, or paste its link into Add. The app reads the page's own title, site, picture and summary. For an article it counts the words and works out the reading time, so it fits the time slots too. Kind pills (Videos, Articles …) appear once you have more than one kind."),
        ("Saving from the phone",
         "In YouTube, tap Share, then More, then WatchLater. The video is on the list before you are back in YouTube — its title and length are filled in the next time this app opens. From Safari or any other app, Share → WatchLater works the same way."),
        ("Saving from the Mac",
         "Press Add. \"Take Safari's page\" saves whatever Safari is showing (macOS asks once whether WatchLater may talk to Safari). Or paste one link, many links, or a playlist link — a playlist adds every video in it, in order."),
        ("One list on both devices",
         "The list lives in your iCloud Drive, in a folder only this app sees. Each device merges its changes into the file, so nothing one device did is lost because the other was busy. Without iCloud, the list stays on the device."),
        ("Watching and the Library",
         "When you come back to a video you opened, the card asks whether you finished it — one tap answers. Watched (or Read) moves a card into the Library, where it keeps its marks and notes; Back to the list returns it."),
        ("Pin, Together, Note, Tags",
         "The pin keeps a card at the top. Together marks a video to watch with someone: the Together pill shows them all and copies one link that plays them in order, or a message with the titles. A note is a line in your own words; tags are your own words too, each becoming a filter."),
        ("Plan an evening",
         "Say how many minutes you have and the app picks a set from what is on screen that fills the time as closely as it can. Try another for a different set; Open as one playlist plays them in a row — on the Mac, the phone or the television."),
        ("Shorts",
         "A Short (or anything a minute or less) stays out of the timed slots and out of a planned evening, has its own pill, and is marked SHORT on the card."),
        ("Three months",
         "A video that has waited three months without being kept gets an amber edge and two buttons: Keep, or the bin. The bin can be undone for a few seconds; on the other device the card simply disappears."),
        ("Your data",
         "Settings shows where the list lives, imports the old app's watchlater.json, and writes a backup wherever you choose. Nothing about your list ever leaves your devices and your iCloud."),
    ]
}
