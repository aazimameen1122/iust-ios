# IUST — iOS app (v2.22, port of the Android app)

Single-purpose wrapper around the IUST Student Login portal
(`https://studentservice.iust.ac.in/Account/login`), matching the Android app
feature-for-feature where iOS allows it.

## What's inside (ported from Android v2.22)

- Opens straight to Student Login — no home screen, like you asked
- Navy/gold theme, gold progress bar, loading + error screens with retry
- Pull-to-refresh, edge-swipe back/forward
- Session cookies persist (staying logged in works)
- **Biometric saved login** — Face ID / Touch ID unlocks the Keychain-stored
  ID + password, fills the form, ticks "Remember me?"
- **Captcha policy (same as Android):** the portal's code field is filled in,
  focused, and NEVER auto-submitted or auto-solved. You type the code and tap
  Log in yourself. (The field is spelled "Capcha" — the detector matches it.)
- **Attendance tracking** — menu → Track attendance scrapes the View
  Attendance table, saves subjects, color-codes them (<75% red = exam line,
  <85% amber = warning), and feeds the home-screen widget
- **Page watchers** — watch results/notices/attendance pages, get a baseline
  hash; re-checked when the app returns to foreground
- **In-app PDF viewer** for portal downloads (PDFKit)
- Dark mode toggle, "Open in Safari", page-structure diagnostics
- Auto-update interval picker (Off / 15m / 30m / 1h / 6h / 12h / Daily)

## Honest iOS limits (not bugs — Apple restrictions)

- **No exact background sync.** Android's WorkManager chain can't exist on
  iOS. Background App Refresh is opportunistic — iOS decides when the app
  wakes. The widget refreshes on its own budget (~40–70 reloads/day, roughly
  every 15–60 min when visible); the system may honor reloads late.
- **Widget needs a paid Apple Developer account** ($99/yr) for the App Group
  (`group.com.mussey.iustapp`) that shares attendance data. The widget source
  is in `IUSTWidget/` — add it as a Widget Extension target in Xcode. Without
  the App Group it shows a "open the app" placeholder.
- **No headless background login.** The attendance auto-tracker runs in the
  foreground web view only. If the portal shows a captcha, background sync
  can't get past it — same fail-fast rule as Android.

## Build it

### Option A — you have access to any Mac (5 min)

1. On the Mac: `brew install xcodegen`, then `xcodegen generate` in this folder
   (or: Xcode → New → Project → iOS App `IUST`, SwiftUI, and drag these
   `.swift` files + `Assets.xcassets` in).
2. Set the team to your Apple ID, connect your iPhone, press ⌘R.
3. To add the widget later: Editor → Add Target → Widget Extension, add
   `IUSTWidget/IUSTWidget.swift`, enable the App Group capability on both
   targets (needs the paid developer account).

### Option B — no Mac at all (free, ~15 min of cloud time)

1. Create a free GitHub account, push **this folder's contents** to a new repo
   (so `project.yml` and `.github/` sit at the repo root).
2. Go to Actions → "Build unsigned IPA" → Run workflow (also runs on push).
3. Download the `IUST-unsigned-ipa` artifact → you get `IUST-unsigned.ipa`.
4. Sideload it with [Sideloadly](https://sideloadly.io/) (Windows) or AltStore
   using your free Apple ID. Re-sign weekly — free Apple ID certs expire
   after 7 days, that's Apple's rule, not the app's.

## Files

| File | Port of |
|---|---|
| `ContentView.swift` | `BrowserActivity.java` (menus, sheets, actions) |
| `PortalWebView.swift` | WebView setup (progress, refresh, cookies, PDF intercept) |
| `PortalLogin.swift` | `PortalLogin.java` (captcha detect + autofill JS) |
| `CredentialStore.swift` | `CredentialStore.java` + `BiometricHelper.java` (Keychain + Face ID) |
| `AttendanceStore.swift` | `AttendanceStore.java` (thresholds, persistence) |
| `WatcherStore.swift` | `WatcherStore.java` (page watchers) |
| `PDFViewer.swift` | `PdfViewerActivity.java` |
| `WidgetBridge.swift` | `WidgetCenter.reloadAllTimelines()` call |
| `IUSTWidget/IUSTWidget.swift` | `AttendanceWidgetProvider` (needs App Group + paid account) |
| `project.yml` | xcodegen spec for CI builds |
| `.github/workflows/ios.yml` | free cloud-mac IPA build |
