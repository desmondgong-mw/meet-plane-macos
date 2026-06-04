# MeetPlane ✈️

A lightweight macOS menu-bar app that connects to Google Calendar, detects upcoming Google Meet meetings, and shows a fun animated notification 5 minutes before each meeting starts.

A plane flies across your screen pulling a flag banner that reads:
```
[Design Review · 2:30 PM] ——— ✈️
```

---

## Features

- 🍎 Native macOS app (SwiftUI + AppKit)
- 📅 Google Calendar OAuth 2.0 integration
- 🎥 Automatic Google Meet event detection (`hangoutLink` / `conferenceData`)
- ✈️ Transparent, non-blocking plane + flag animation
- 🔔 Reminder fires 5 minutes before each meeting
- 🔒 OAuth tokens stored securely in macOS Keychain (not UserDefaults)
- ⚡ **Test animation works immediately — no Google auth required**

---

## Requirements

- macOS 13.0 (Ventura) or later
- Xcode 15+
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`)
- A Google Cloud project with the **Google Calendar API** enabled

---

## Quick Start (Test Animation — No Auth Needed)

```bash
git clone https://github.com/desmondgong-mw/meet-plane-macos.git
cd meet-plane-macos
xcodegen generate
open MeetPlane.xcodeproj
```

1. Press **⌘R** in Xcode to build and run.
2. Click the **✈️** icon in the menu bar.
3. Click **"Run Test Animation"** — the plane flies across your screen immediately.

---

## Full Setup (with Google Calendar)

### 1. Generate the Xcode Project

```bash
brew install xcodegen   # if not already installed
xcodegen generate
open MeetPlane.xcodeproj
```

> The `*.xcodeproj` directory is git-ignored. Always regenerate it with `xcodegen generate` after cloning.

### 2. Set Up Google OAuth Credentials

#### Step 1 — Create a Google Cloud Project

1. Go to [Google Cloud Console](https://console.cloud.google.com/).
2. Create a new project (e.g. **MeetPlane**).
3. Navigate to **APIs & Services › Library**, search for **Google Calendar API**, and enable it.

#### Step 2 — Create OAuth 2.0 Credentials

1. Go to **APIs & Services › Credentials**.
2. Click **+ Create Credentials › OAuth client ID**.
3. Choose **iOS** as the application type (supports custom URI redirect schemes, same as macOS native apps).
4. Set the **Bundle ID** to `com.meetplane.app`.
5. Note your **Client ID** (the client secret is not required for PKCE, but useful for the MVP code-exchange stub).

#### Step 3 — Configure the App

Open `MeetPlane/GoogleAuthManager.swift` and replace the placeholders:

```swift
private enum OAuthConfig {
    static let clientID     = "YOUR_CLIENT_ID.apps.googleusercontent.com"
    static let clientSecret = "YOUR_CLIENT_SECRET"   // optional with PKCE
    ...
}
```

#### Step 4 — Add the Redirect URI

In Google Cloud Console, add this to the authorized redirect URIs for your OAuth client:

```
com.meetplane.app:/oauth2callback
```

### 3. Complete the Token Exchange (P0 TODO)

The OAuth browser redirect and URL capture are wired up, but `GoogleAuthManager.exchangeCodeForTokens(_:)` is a stub. See the inline `TODO` comments in that method to complete the POST to Google's token endpoint. This is the only required step before end-to-end Google auth works.

### 4. Run the App

1. Select **My Mac** as the run destination in Xcode.
2. Press **⌘R**.
3. The **✈️** icon appears in your menu bar.
4. Click **Sign In with Google**, complete the browser flow, and your meetings will load.

---

## Required OAuth Scope

```
https://www.googleapis.com/auth/calendar.readonly
```

This is a read-only scope. MeetPlane never writes to your calendar.

---

## Architecture

```
MeetPlane/
├── MeetPlaneApp.swift              # App entry point, MenuBarExtra + AppDelegate
├── AppState.swift                  # Central coordinator, ties all managers together
├── AppMenuView.swift               # Menu bar dropdown UI
├── GoogleAuthManager.swift         # OAuth 2.0 browser flow + token management
├── GoogleCalendarClient.swift      # Google Calendar REST API client
├── MeetingEvent.swift              # Internal data model for a Meet event
├── MeetingReminderScheduler.swift  # In-memory Timer-based reminder scheduler
├── PlaneOverlayWindow.swift        # Transparent borderless NSWindow overlay
├── PlaneBannerView.swift           # SwiftUI plane + flag animation
├── SettingsView.swift              # Preferences window
└── KeychainTokenStore.swift        # Secure OAuth token persistence
```

### How It Works

1. **Auth** — The app opens Google's OAuth page in the browser. After the user signs in, Google redirects to `com.meetplane.app:/oauth2callback`. macOS delivers this URL to the app via `NSApplicationDelegate.application(_:open:)`. The app exchanges the code for tokens and stores them in the Keychain.

2. **Polling** — Every 5 minutes, `GoogleCalendarClient` fetches events from the primary Google Calendar for the next 24 hours. Events without a `hangoutLink` or `conferenceData` video entry point are discarded. All-day events, cancelled events, and declined events are also filtered out.

3. **Scheduling** — `MeetingReminderScheduler` creates one `Timer` per event that fires 5 minutes before the event's start time.

4. **Animation** — When the timer fires, `PlaneOverlayWindow` (a transparent, borderless `NSWindow` with `ignoresMouseEvents = true`) is shown. `PlaneBannerView` animates the flag + rope + plane assembly from off-screen left to off-screen right in ~10 seconds, then the window is dismissed.

---

## Menu Bar Options

| Item | Action |
|------|--------|
| Meeting list | Click to open the meeting in Google Meet |
| **Refresh Meetings** | Manually trigger a calendar fetch |
| **Run Test Animation** | Preview the plane animation (no auth required) |
| **Settings…** | Open preferences |
| **Sign In with Google** | Start the OAuth flow |
| **Sign Out** | Remove stored credentials |
| **Quit MeetPlane** | Exit the app |

---

## Current MVP Limitations

| Limitation | Detail |
|------------|--------|
| ⚠️ Token exchange is a stub | `exchangeCodeForTokens` must be completed — see `TODO` in `GoogleAuthManager.swift` |
| ⚠️ No token refresh | Access tokens expire after ~1 hour; re-sign-in required |
| ⚠️ Primary calendar only | Events from secondary/shared calendars are not fetched |
| ⚠️ No persistence across restarts | In-memory timers are lost when the app quits |
| ⚠️ No catch-up on launch | Events starting in < 5 min when the app starts are not announced |
| ⚠️ Client secret in source | Use PKCE (no secret) for production |

---

## TODO

See [TODO.md](TODO.md) for the full prioritised task list.

---

## License

MIT
