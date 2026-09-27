# Getting AMS WatchLater onto the iPhone and the Mac (TestFlight)

Everything is automated except one thing only the account owner can do, once.
After that, a new version is one click: **Actions → TestFlight → Run workflow**.

## 1. Create the app's record in App Store Connect (browser, once)

1. Open <https://appstoreconnect.apple.com> and sign in.
2. **My Apps → the "+" → New App.**
3. Tick **both** platforms: **iOS** and **macOS** (one app, two platforms).
4. Name: **AMS WatchLater**. Bundle ID: **com.schabbauer.AMSWatchLater**. SKU: `AMSWatchLater`.
5. Create. Nothing else on that page matters for TestFlight.

Then, still in App Store Connect: **TestFlight → Internal Testing → "+"** → make
a group called **Martin** and add yourself to it.

## 2. Secrets

The four repository secrets (`ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_KEY_P8`,
`ASC_TEAM_ID`) are the same as on AMS Packing; the key must have the **Admin**
role (an App Manager key cannot cloud-sign).

## 3. Ship

**Actions → TestFlight → Run workflow.** It runs the whole test suite first (a
red suite ships nothing), then builds for the iPhone and for the Mac, sends both
to TestFlight and releases them to the Martin group. Apple takes a few minutes;
then the TestFlight app on each device offers it.

## First run on a device

- Both devices must be signed in to the same iCloud account; the list appears
  on the second device within a minute of the first write.
- On the Mac: **Your data → Import watchlater.json** and pick the web app's file
  (`App Development/AMS WatchLater/watchlater.json`). Once.
- On the iPhone: in YouTube, **Share → More → WatchLater**. The first time,
  scroll the share sheet's app row to the end, tap **More**, and switch
  WatchLater on so it stays visible.
- On the Mac: the first **Take Safari's page** asks whether WatchLater may
  control Safari — click OK.
