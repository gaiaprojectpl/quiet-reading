# Quiet Reading – context for Claude

Calm reading tracker for iPhone (incl. **iPhone Duo**) and Android, built around beautiful Home Screen widgets.
Owner: Kaja (product/design, not a developer – explain steps plainly, no jargon, one question at a time).
Brand is standalone (not Ibexa). Pastel, delicate, aimed at women readers. **WCAG 2.2 AA is a hard requirement.**

- Figma (source of truth for UI): https://www.figma.com/design/dw4Stk6aD7oiLaBANzIOCR
  Pages: 🧱 Components (all components + variables), 🎇 UI test (Flows 0–10, iOS + Android rows, errors/edge cases), 🖼️ Graphics, 📱 Prototype.
- Coded clickable prototype: https://claude.ai/artifact/8rxHGvZqe7ULazEQbH7d5P
- Bundle ID / package: `app.quietreading` · display name "Quiet Reading" · English only (but every string localizable).

## Repo layout
```
ios/QuietReading.xcodeproj   Xcode 27 project (new text format project.xcproj, folder-synced: files in ios/QuietReading/ are picked up automatically)
ios/QuietReading/            App/, DesignSystem/ (Tokens.generated.swift, Theme.swift, Components/), Features/<Area>/
android/                     Gradle project, module :app, package app.quietreading
android/app/src/main/java/app/quietreading/   designsystem/ (Tokens.generated.kt, QsTheme.kt, components/), feature/, MainActivity.kt
design-tokens/tokens.json    exported from Figma variables
tools/generate_tokens.py     tokens.json → Swift + Kotlin (never edit *.generated.* by hand)
Secrets.env                  API keys (git-ignored). Template: Secrets.example.env
```

## Build & run
iOS (simulator; free Apple ID can't sign for device without the phone connected):
```
xcodebuild -list -project ios/QuietReading.xcodeproj
xcodebuild -project ios/QuietReading.xcodeproj -scheme QuietReading -destination 'platform=iOS Simulator,name=iPhone 17' build
xcrun simctl boot "iPhone 17"; open -a Simulator
```
Android (AVD "Pixel 9" exists):
```
cd android && ./gradlew assembleDebug
~/Library/Android/sdk/emulator/emulator -avd Pixel_9 &   # check name: emulator -list-avds
./gradlew installDebug && ~/Library/Android/sdk/platform-tools/adb shell am start -n app.quietreading/.MainActivity
```
Tokens: `python3 tools/generate_tokens.py` after any change to design-tokens/tokens.json.
Always build after changes and fix errors before reporting done. Take simulator/emulator screenshots to compare with Figma.

## Tech decisions
- iOS: Swift 6, SwiftUI, min iOS 18, iPhone only. Target uses **MainActor default isolation** → shared/background/widget types must be `nonisolated` (generated tokens already are). WidgetKit + App Intents (interactive widgets), ActivityKit (Live Activity), SwiftData in an App Group (`group.app.quietreading`) so widgets read the same data. StoreKit 2. VisionKit/Vision for cover + page text (on-device).
- Android: Kotlin, Jetpack Compose + Material 3, min API 26. Glance widgets, Room + DataStore, Play Billing, CameraX + ML Kit (on-device).
- Payments via RevenueCat later (one-time **Plus $4.99**, no subscription, no Family Sharing). Until then StoreKit testing config / stubs.
- Book data: Hardcover GraphQL (token in Secrets.env as HARDCOVER_TOKEN; personal token – don't ship it in the app binary for release), Open Library, Google Books (optional key). Import: Goodreads CSV + public shelf RSS, StoryGraph CSV, Kindle My Clippings.txt.
- Accounts are in scope (Apple, Google, email; "Not now" must keep the app fully usable – App Store 5.1.1). **Backend not chosen yet** (Supabase vs Firebase) – build local-first, add accounts/sync after core works. Need in-app account deletion + data export (GDPR).
- No Kotlin Multiplatform. No social feed, no ads, no streak pressure.

## Design system rules
- Never hard-code colours, radii, spacing, sizes, durations. iOS: `theme.palette.ink`, `theme.radii.btn`, `Space.s16`, `Size.button`, `Motion.base`. Android: `QsTheme.colors.ink`, `QsTheme.shapes.btn`, `QsSpace.s16`, `QsSize.button`, `QsMotion.base`.
- 6 theme modes: Peach & Sage (free default), Clay & Cream / Blush & Ivory / Lavender & Mist (Plus), **Night** (system dark mode, free), **High contrast** (Increase Contrast / Android 14 contrast, free). Resolution: high contrast > dark > chosen.
- `accentInk` for accent-coloured text/icons on soft/soft2 backgrounds; `lineStrong` for input/control borders (3:1); `line` only for dividers.
- Heading font per theme (Newsreader / Fraunces / Lora / Playfair Display – all OFL, still to bundle); body = system (SF / Roboto). Support Dynamic Type / font scaling everywhere.
- Icons: Tabler Icons (MIT), outline, stroke 1.5 (current Android drawables and SF Symbols are placeholders).
- Touch targets ≥ 44 pt iOS / 48 dp Android. Inputs 40 high with 1 px lineStrong border; error = red border/icon/helper, label stays neutral.
- One navigation everywhere: Home · Library · Add · Stats · Settings (Add = accent circle in design). iPhone Duo open = side rail.
- Progress is TYPED (number keyboard opens), never +/− steppers. Current book buttons: Update + Finished.
- Notifications: one component, always at the top under the status bar, auto-hide 4 s (6 s with action). Saving is silent.
- Charts: one hue per theme, values on chart, one-line text summary, never colour alone.
- Gamification "collect, don't compete": stamps, shelf of spines, flexible weekly rhythm (rest days = moon). No XP, leaderboards or resetting streaks.

## UX writing (see Figma Flow 10)
- Title says what is true now ("Your shelf is ready"), body is one calm sentence with the next step or reassurance.
- No "Oops", no blame, no exclamation marks, no error codes. Reassure about data first ("Your books are safe on this phone").
- Buttons are verbs (Add a book, Try again, Add by hand). Sentence case. The app never says "I".
- Loading: < 0.3 s nothing; 0.3–8 s skeletons in the real layout (disabledBg, no shimmer); > 8 s explain + offer a way out.
- Offline = Info banner, never a blocking dialog; saving always works offline; details/covers fill in later.
- Payments: no dark patterns, real price only, say "you weren't charged" when true.

## Build order (all flows are in v1)
1. Core: data model, book search, add (search / barcode / cover photo), update & finish, library, book details, first launch & import (Flows 1, 2, 3, 7)
2. Widgets: current book (interactive Update), goal, wooden shelf, Lock Screen, StandBy, Live Activity
3. Stats & gamification (8, 8b), quotes (9), settings & profile (4)
4. Plus themes & payment (5)
5. Accounts & sync (0) – after backend choice
6. iPhone Duo postures + Pencil margin notes (6, 6b) – test on Kaja's real iPhone Duo (iOS 27.1 ArrangementView, reservedRegions, onHingeChange; PencilKit)
Each feature: iOS first, then Android parity. Include empty/loading/offline/error states from Flow 10.

## Status (26 Nov 2026)
- Both projects created; shell app with 5 tabs, theme switching, QsButton and EmptyState components on iOS and Android. Not yet verified to compile – build both first.
- Placeholder icons; fonts not bundled yet.
- If `_to_delete_android_old/` still exists, it is an old wrong Android project – ask Kaja to delete it (don't commit it).

## Git
Repo: github.com/gaiaprojectpl/quiet-reading (private). Commit in small steps with clear messages. Ask Kaja before pushing. Never commit Secrets.env, keystores or google-services files.
