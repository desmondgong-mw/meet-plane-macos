# MeetPlane — TODO

## P0 — Required for Basic End-to-End Function

- [ ] **Complete `exchangeCodeForTokens(_:)` in `GoogleAuthManager.swift`**  
  POST to `https://oauth2.googleapis.com/token` with `code`, `client_id`, `client_secret`, `redirect_uri`, `grant_type=authorization_code`.  
  Parse `access_token`, `refresh_token`, `expires_in` from the JSON response.  
  Save both tokens to `KeychainTokenStore`.
- [ ] **Implement token refresh** — use the stored refresh token to silently obtain a new access token when the current one is expired.
- [ ] **Test end-to-end** — sign in → fetch meetings → see reminders scheduled → animation fires.

## P1 — Important UX

- [ ] Graceful error UI when Calendar fetch fails (e.g. 401 → prompt re-login, network error → show message).
- [ ] On app launch, schedule reminders for events that start more than 5 minutes in the future (catch-up logic).
- [ ] Prevent duplicate reminders when calendar is refreshed while a timer is already pending for the same event.
- [ ] Show "last refreshed" timestamp in menu.

## P2 — Nice to Have

- [ ] **PKCE flow** — remove client secret from source code; use `code_verifier` + `code_challenge` for the auth request.
- [ ] **Multiple calendars** — fetch from all writable calendars, not just `primary`.
- [ ] **Configurable lead time** — wire `SettingsView.reminderLeadMinutes` to `MeetingReminderScheduler.leadTime`.
- [ ] **Configurable refresh interval** — wire `SettingsView.refreshIntervalMinutes` to `AppState.setupPeriodicRefresh()`.
- [ ] **Click banner to join** — make the overlay window interactive on click, opening the meet link.
- [ ] **Sound effect** — play a short chime when the animation starts.
- [ ] **Auto-launch at login** — use `SMAppService.mainApp.register()`.
- [ ] **macOS Notification Center fallback** — post a `UNUserNotification` in addition to the animation.

## P3 — Polish

- [ ] Custom app icon as a template image (monochrome `NSImage` for the menu bar).
- [ ] Replace ✈️ emoji with a custom drawn `Path` or SF Symbol for better visual integration.
- [ ] Spring/ease-in-out animation curve instead of pure linear.
- [ ] Dynamic flag width based on measured text size (replace character-count estimate).
- [ ] Dark/light mode–adaptive flag gradient colors.
- [ ] Localisation.

## Known Issues

- OAuth token exchange is not implemented — `isAuthenticated` will never become `true` from a real Google sign-in until P0 is complete.
- Custom URL scheme delivery via `NSApplicationDelegate.application(_:open:)` requires the URL scheme to be registered in `Info.plist` (already done) **and** the app to be code-signed or run from Xcode.
