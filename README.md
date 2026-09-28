# AMS WatchLater (native)

A list of YouTube videos to watch, sorted by the time you have — on the Mac and
on the iPhone, one list through iCloud. The native successor of the web app in
`AMS WatchLater` (Node engine + Safari page), which it replaces: no engine, no
port, no login item, no drop folder, no shortcut.

## Layout

- `Core/` — Swift package `WatchLaterCore`: the model (videos, the file and its
  merge, YouTube link/page parsing, time slots, the evening planner, Together).
  `cd Core && swift test` runs its tests in seconds.
- `App/Sources/` — the SwiftUI app, one target for iPhone and Mac.
- `App/Share/` — the iPhone share extension (Share → WatchLater).
- `UITests/` — XCUITest, found by accessibility identifier only (`wl-…`).
- `project.yml` — XcodeGen spec; `xcodegen generate` makes the `.xcodeproj`.
- `tools/build.sh [build|test] [iphone|mac] [icloud]` — local builds outside
  `~/Documents` (codesign refuses xattrs there).
- `.github/workflows/tests.yml` — every push: model tests, UI tests on iPhone
  and Mac. `testflight.yml` — by hand: tests, then archive + upload for both
  platforms, released to the *Martin* group. See `TESTFLIGHT.md`.

## Data

`watchlater.json` — the web app's format plus `modifiedAt` per card. Lives in
the app's iCloud container (`Documents/`), or Application Support without
iCloud. Every write merges against the file first (`LibraryFile`); a removal is
a tombstone kept 30 days so the other device hears about it. A dated safety
copy is written once a day beside the file and never replaced by a smaller one.
Thumbnails are per-device, in Caches.

## Doors for a link

- iPhone: the share extension writes straight into the iCloud file (bare card;
  the app fills title/length next time it looks) or, without iCloud, into the
  app group inbox.
- Mac: Add sheet (paste, or "Take Safari's page" via Apple events), and the
  URL scheme `amswatchlater://add?url=…`.
- Mac, one keystroke: `~/Applications/Add to WatchLater.app` (Raycast), built by
  `tools/launcher/build.sh` from `add-to-watchlater.applescript` — reads Safari's
  (or Chrome's) front page and opens `amswatchlater://add?url=…` in the background.

The old web app (Node engine on :7821, Dock/Raycast applets, iCloud drop folder)
was retired on 2026-09-28: folder `Legacy/AMS WatchLater (web app)`, GitHub repo
`AMS-WatchLater` archived. Nothing was left in it that this app does not have.
