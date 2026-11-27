# Figma → code rules (Quiet Reading)

How to turn a Figma node into native code in this repo. Read with `CLAUDE.md` (product, UX-writing and accessibility rules live there and are not repeated here).

Figma files: **playground** `Tq6PW3rvfMxncJfpmyjKoz` (default for MCP) and **quiet-reading** `F2BQfzE22CMwMkI4gZXZNe` (private master, MCP rate-limited). They're copies with the same node IDs. Use the one Kaja links, otherwise playground (see CLAUDE.md). Components and variables are on the page 🧱 Components (`46:8`); mockups are on 🎇 Mockups (`1:301`).

Where things are on 🎇 Mockups (all in Peach & Sage, inside `32:27 Flows`). Each flow is split into an iOS frame and an Android frame. Open the iOS frame when building iOS (checked 27 Nov 2026):

| Flow | iOS | Android |
|---|---|---|
| 0 Onboarding & account | `109:14162` | `109:14163` |
| 1 First launch & import | `109:14168` | `109:14169` |
| 2 Add a book by photo | `109:14174` | `109:14175` |
| 3 Update progress & finish | `109:14180` | `109:14181` |
| 4 Settings & profile | `109:14186` | `109:14187` |
| 5 Plus themes & payment | `109:14216` | `109:14217` |
| 6 iPhone Duo & foldables | `109:14222` | `109:14223` |
| 6b Duo: every screen adapts | `109:14228` | `109:14229` |
| 7 Library & book details | `109:14192` | `109:14193` |
| 8 Stats & year in books | `109:14198` | `109:14199` |
| 8b Charts & gamification | `109:14204` | `109:14205` |
| 9 Add a quote | `109:14210` | `109:14211` |
| 10 Empty, loading & offline | `109:14241` | `109:14242` |
| 11 Splash animation | `153:14821` | `153:15017` |
| Widget ideas | `109:14235` | `109:14236` |

If a node isn't found, Kaja has probably moved it: run `get_metadata` on `32:27` (not on the whole page) to find the new ID, then update this table.

Theme previews (F/C/D/E): `57:5791`. **Ignore the "Earlier static screens" frames (`28:2`–`31:2`)**: they are marked outdated. The page is very large, so don't run `get_metadata` on `1:301`. Go straight to a flow node.

## 0. Workflow for every Figma node

1. Run `create_session` with the file key in use (default playground `Tq6PW3rvfMxncJfpmyjKoz`), then `get_design_context` and `get_screenshot` for the node. If the node uses variables, also run `get_variable_defs`.
2. Treat the code that `get_design_context` returns (React + Tailwind) as a **reference only**. This project has no web code. Rewrite it in **SwiftUI** (iOS) and then **Jetpack Compose** (Android).
3. Map every Figma variable to its token by name (section 1). If a value has no variable, use the nearest token and tell Kaja which value in Figma is missing a variable. Do not hard-code the raw value.
4. Use an existing component first (section 2). Make a new shared component only if the Figma node is an instance from 🧱 Components. Otherwise build it inside the feature folder.
5. Build both platforms, take a simulator/emulator screenshot in at least Peach & Sage and Night, and compare it with the Figma screenshot.

## 1. Tokens

**Source:** `design-tokens/tokens.json`, exported by hand from the Figma variable collections *App themes*, *Spacing* and *Foundations*.
**Transform:** `python3 tools/generate_tokens.py` writes
- `ios/QuietReading/DesignSystem/Tokens.generated.swift`
- `android/app/src/main/java/app/quietreading/designsystem/Tokens.generated.kt`

Never edit `*.generated.*` files. To change a token, edit `tokens.json` (or re-export from Figma) and run the script again.

### JSON structure
```jsonc
{
  "themes": {
    "modes": ["peachSage","clayCream","blushIvory","lavenderMist","night","highContrast"],
    "plus":  [false,true,true,true,false,false],
    "colors": { "ink": ["#33302C", …one value per mode…], … },   // 30 colour roles
    "radius": { "card": [20,6,28,24,20,20], … },                 // card btn cover chip sheet field inner
    "headFont": { "family": [...], "weight": [...] }
  },
  "space":  { "s0":0, "s2":2, "s4":4, "s8":8, "s12":12, "s16":16, "s20":20, "s24":24, "s32":32, "s40":40, "s48":48, "s64":64, "s80":80 },
  "size":   { "touchIos":44, "touchAndroid":48, "field":40, "button":48, "buttonSmall":40, "iconS":16, "iconM":20, "iconL":24, "coverS":48, "coverM":72, "coverL":120, "stroke":1, "focusRing":2 },
  "motion": { "fast":150, "base":250, "slow":400, "toastShort":4000, "toastLong":6000 },  // ms (Swift: seconds)
  "opacity":{ "scrim":0.4, "pressed":0.12 }
}
```
Each theme array is indexed by the position of the mode in `modes`. When you add a mode or a role, every array must get a value.

### Figma variable → code

In this file, Figma MCP shows variables as CSS names (`var(--qs-…)`). Convert kebab-case to camelCase: `--qs-success-soft` → `successSoft`, `--qs-chart-track` → `chartTrack`.

| Figma variable (as MCP shows it) | SwiftUI | Compose |
|---|---|---|
| `--qs-ink`, `--qs-accent-ink`, `--qs-soft2`… | `theme.palette.ink` | `QsTheme.colors.ink` |
| `--qs-radius-card`, `--qs-radius-btn`… | `theme.radii.card` | `QsTheme.shapes.card` (a `Dp`, wrap in `RoundedCornerShape(...)`) |
| `--qs-space-16` | `Space.s16` | `QsSpace.s16` |
| `--qs-font-head` / `--qs-font-head-weight` | `theme.headline(…)` | `QsTheme.headFamily` |
| size `button`, `iconM`, `coverM` | `Size.button` | `QsSize.button` |
| motion `base` | `Motion.base` (seconds) | `QsMotion.base` |
| opacity `scrim` | `Opacity.scrim` | `QsOpacity.scrim` |

Reading the theme:
```swift
@Environment(\.theme) private var theme          // already resolved (high contrast > Night > chosen)
Text("…").foregroundStyle(theme.palette.ink2)
    .background(theme.palette.surface, in: RoundedRectangle(cornerRadius: theme.radii.card, style: .continuous))
```
```kotlin
val c = QsTheme.colors
Text("…", color = c.ink2,
     modifier = Modifier.background(c.surface, RoundedCornerShape(QsTheme.shapes.card)))
```
On iOS, always use `RoundedRectangle(cornerRadius:style: .continuous)`, which matches Figma corner smoothing.

### Colour roles: which one to use
- Page background `bg`, cards/sheets `surface`, body text `ink`, secondary text `ink2`.
- Accent-coloured text/icons on `soft`/`soft2` (or on any light background): **`accentInk`**, never `accent` (contrast).
- Filled accent controls: `accent` bg + `onAccent` text; pressed `accentPressed`.
- Input / control borders: `lineStrong` (3:1). Dividers only: `line`.
- Status: `error`/`errorSoft`, `success`/`successSoft`, `warning`/`warningSoft`, info = `infoSoft` bg + `ink` text.
- Disabled and skeletons: `disabledBg` + `disabledInk`.
- Focus ring: `focus`, width `Size.focusRing`.
- Charts: `accent` (main series), `chart2–4`, `chartTrack` for the empty part.
- Toast / snackbar: `inverse` bg + `onInverse` text.

### Not tokenised yet (known gaps)
- **Typography** has no tokens. Body text uses system text styles: iOS `.body`, `.subheadline`, `.footnote`… (these support Dynamic Type); Android uses `sp` values from the Figma text style. Headings use the theme serif: iOS `theme.headline(size, relativeTo: .title2)`, Android `fontFamily = QsTheme.headFamily`. If Figma uses a text style, use its size and add a comment with the style name. Suggest adding type tokens to Kaja instead of inventing a scale.
- **Icon-circle sizes** (80 in EmptyState) and some icon sizes are hard-coded in the current components. Do not copy that. Use `Size.*` or ask for a token.
- Heading fonts (Newsreader, Fraunces, Lora, Playfair Display) are bundled on iOS in `ios/QuietReading/Resources/Fonts/` (variable TTFs + OFL licences) and registered at launch by `QsFonts.register()` (the target generates its Info.plist, so there's no `UIAppFonts`). Android still falls back to `FontFamily.Serif`.

## 2. Components

Figma component properties use these names (renamed 27 Nov): **Priority** (Primary / Secondary / Outline / Text / Destructive), **Size** (Small / Medium / Large / Extra large), **State** (Enabled / Active = pressed / Focus / Disabled / Selected / Selected active / Selected focus / Loading), **Selection**, **Selected item**, **Type**. Code mirrors them (e.g. `QsButtonStyle(priority: .destructive, size: .small)`).

Where things live on 🧱 Components (`46:8`): Button `47:2`, Navigation `47:166` (nav bar, nav item, back button), **iPhone Duo `195:1481`** (Duo rail `131:1705`, system column), Books `69:9751` (cover, current book card, grid cell, progress), Notifications & banners `47:1083`, Settings & system `72:9822`, **Widgets Final `177:16015`** (Widget 2/Free · …, Widget 2/Plus · Soft / Colourful / Modern …, Widget 2/System · Lock Screen / StandBy – use these for the widget phase; the old "C · Widgets" section is gone), Component specification `200:1481`.

Variables: colours in "App themes" (`c/…`, one mode per theme) now alias "Palette primitives" (`peach/100`, `sage/700`…). Always resolve to the final value; the app keeps the resolved per-theme values in `tokens.json`. `c/system/*` (camera, keyboard, hardware) only draw devices in mockups – not app tokens. "zz Legacy (do not use)" is ignored.


| Figma (🧱 Components) | iOS | Android |
|---|---|---|
| Button: Priority = Primary / Secondary (accent border, no fill) / Outline (neutral border) / Text / Destructive · Large 48 / Small 40 | `Button("…"){}.buttonStyle(QsButtonStyle(priority: .secondary, size: .small))` – `DesignSystem/Components/QsButtonStyle.swift` | `QsButton("…", onClick, kind = QsButtonKind.Primary)` – `designsystem/components/QsButton.kt` |
| Empty state | `EmptyStateView(systemImage:title:message:)` | `EmptyState(icon, title, message)` |
| Screen shell (bg, margins, serif large title) | `ScreenScaffold(title:) { … }` (20 pt sides; system nav bar hidden, title is `ScreenTitle`) | `Screen(title) { … }` (16 dp sides) |
| Nav bar: Home · Library · Add · Stats · Settings | `QsTabBar` (custom, matches Figma: soft/soft2/tintStrong pills, Add = accent circle that opens the Add **sheet**, never a tab) used in `App/RootView.swift` | `MainActivity.kt` (`NavigationBar`) |
| Book cover (2:3, cover radius, shadow, placeholder) | `BookCover(source: .data(book.coverData) / .asset("cover.…"), width:)` | – |
| Progress bar (M 8 pt / S 4 pt) | `QsProgressBar(value:, size: .m / .s)` | – |
| Back button (iOS: chevron + "Back", 44 pt) | `QsBackButton()`. Onboarding hides the system nav bar and shows this; the edge swipe still works | – |
| Banner · info | `InfoBanner(message:)` | – |
| Logo | `QsLogo()` | – |

Component architecture:
- **iOS:** small SwiftUI `View`s / `ButtonStyle`s. They read `@Environment(\.theme)` and `@Environment(\.isEnabled)` themselves, so callers never pass colours. Variants are a nested `enum Kind`. Text parameters are `LocalizedStringKey`.
- **Android:** stateless `@Composable` functions that take `modifier: Modifier = Modifier` as the first optional parameter. Variants are an `enum class …Kind`. They wrap Material 3 (`Button`, `NavigationBar`…), and `QuietReadingTheme` maps the palette onto `MaterialTheme.colorScheme`, so stock M3 components get the theme colours automatically.
- Start each component with a doc comment that names the Figma component: `/// 🧱 Components › Button …`.
- Names: iOS `Qs<Name>` or `<Name>View`, Android `Qs<Name>` / `<Name>`. Keep the same Figma name on both platforms.
- There is no Storybook. Use `#Preview` (iOS) and `@Preview` (Compose) and add previews for every variant, plus Night and High contrast.
- Code Connect is not set up yet.

New shared components go in `ios/QuietReading/DesignSystem/Components/` and `android/.../designsystem/components/`. Screen-specific views go in `Features/<Area>/` (iOS) and `feature/` (Android).

Before you finish a component, check:
- Touch target ≥ `Size.touchIos` (44) / `QsSize.touchAndroid` (48), even when the visual is smaller (`.contentShape` / `Modifier.minimumInteractiveComponentSize()`).
- Accessibility: decorative icons hidden (`.accessibilityHidden(true)` / `contentDescription = null`), groups merged, headings marked (`.accessibilityAddTraits(.isHeader)` / `semantics { heading() }`).
- Text wraps and grows with Dynamic Type / font scale. Use `minHeight`/`heightIn(min=)` and never a fixed height on text containers.
- Correct in all 6 themes. Check that `radius` changes (Clay & Cream is nearly square) do not break the layout.

## 3. Frameworks and build

| | iOS | Android |
|---|---|---|
| UI | SwiftUI, Swift 6, iOS 18+, iPhone only | Jetpack Compose + Material 3 (BOM 2026.02.01), minSdk 26, target 37 |
| Styling | Modifiers + tokens via `Environment` | Modifiers + tokens via `CompositionLocal` (`LocalThemeId`) |
| Build | Xcode 27 project, folder-synced (new files in `ios/QuietReading/` are added automatically, no pbxproj editing) | Gradle Kotlin DSL, version catalog `android/gradle/libs.versions.toml`, AGP 9.5, Kotlin 2.2 |
| Concurrency | Target defaults to MainActor. Anything used by widgets/background must be `nonisolated` | – |

There is no web code, no CSS, no bundler and no CDN. Ignore Tailwind classes in Figma MCP output, except as a hint for which layout to use.

Layout translation from the Figma MCP output:
- Auto layout vertical/horizontal → `VStack`/`HStack` (spacing `Space.*`) · `Column`/`Row` (`Arrangement.spacedBy(QsSpace.*)`).
- "Fill container" → `.frame(maxWidth: .infinity)` · `Modifier.fillMaxWidth()`. "Hug" → no frame.
- Padding → `.padding(.horizontal, Space.s20)` · `Modifier.padding(horizontal = QsSpace.s16)`.
- Absolute positions / fixed widths in the output: replace with stacks. Screens must adapt from iPhone SE to Pro Max, and to the iPhone Duo open posture (side rail).

## 4. Assets

- iOS: `ios/QuietReading/Assets.xcassets` (currently only `AccentColor`). Put images there as asset catalogue entries (PDF/SVG with "Preserve Vector Data" for illustrations, @2x/@3x PNG only for photos).
- Android: `android/app/src/main/res/drawable/` as VectorDrawable XML. Use `drawable-nodpi` WebP only for raster images.
- Figma page 🖼️ Graphics is the source. Export with the Figma MCP `download_assets` and convert SVG → VectorDrawable for Android. Do not reference Figma localhost/asset URLs in code.
- Book covers are remote (Hardcover / Open Library / Google Books) and loaded at runtime. Show a `disabledBg` placeholder with radius `radii.cover` until the cover loads. No image library has been added yet. Ask before adding one (e.g. Coil on Android).
- Fonts: iOS in `ios/QuietReading/Resources/Fonts/` (any `.ttf` there is registered automatically). Android fonts will go in `res/font/` and replace `QsTheme.headFamily`. Use OFL files only and keep each licence file next to its font.

## 5. Icons

- Target set: **Tabler Icons, outline, stroke 1.5** (MIT). Sizes: `Size.iconS/M/L` (16/20/24).
- iOS: Tabler SVGs in `Assets.xcassets` as template images named `qs.<figma name>` (from `@tabler/icons` 3.24.0, stroke changed to 1.5). Use them as `Image("qs.book")` or `Tab("Home", image: "qs.home", …)`. Figma name → Tabler file so far: home→home, library→books, plus→plus, stats→chart-bar, settings→adjustments-horizontal, book→book, camera→camera. For a new icon, check the matching `Icon/*` in Figma (page 46:8, e.g. home `46:14`) and add the same Tabler SVG the same way. Figma MCP export is rate-limited on the current seat, so download from Tabler directly.
- Android: `res/drawable/ic_qs_<name>.xml` (`ic_qs_home`, `ic_qs_library`, `ic_qs_plus`, `ic_qs_stats`, `ic_qs_settings`, `ic_qs_book`, `ic_qs_camera`, `ic_qs_check`). These are hand-drawn Tabler-style placeholders: 24 dp viewport, black stroke, `strokeWidth 1.5`, round caps and joins, transparent fill. Tint them in code (`Icon(painterResource(R.drawable.ic_qs_home), null, tint = c.accentInk)`) and never bake colour into the XML.
- Use the Tabler name for `<name>` (e.g. Tabler `books` → `ic_qs_books`) so the same icon has the same name on both platforms.
- Every icon is either decorative (hidden from accessibility) or has a label. A button that shows only an icon must have an accessibility label.

## 6. Styling approach

- No global stylesheet. "Global styles" means the theme: iOS `RootView` resolves the theme and injects `.environment(\.theme, …)` + `.tint(accent)`. Android `QuietReadingTheme(chosen)` provides `LocalThemeId` + a Material `colorScheme`. Every screen must be inside these.
- Theme choice is stored in `@AppStorage("themeID")` (iOS) and SharedPreferences `quiet_reading/theme_id` (Android, will move to DataStore). Resolution order: high contrast > system dark (Night) > chosen theme. Do not let screens pick a theme themselves.
- Responsive: flexible stacks, `ViewThatFits` / `BoxWithConstraints` when needed, Dynamic Type and font scale up to the accessibility sizes. Duo open posture = side rail instead of the tab bar (later phase).
- Animation durations come from `Motion.*` and respect Reduce Motion (`@Environment(\.accessibilityReduceMotion)` / `Settings.Global.ANIMATOR_DURATION_SCALE`).

## 7. Project structure

```
design-tokens/tokens.json          Figma variables (source)
tools/generate_tokens.py           JSON → Swift + Kotlin
ios/QuietReading/
  App/                             QuietReadingApp, RootView (tabs + theme resolution)
  DesignSystem/                    Tokens.generated.swift, Theme.swift, Components/
  Features/<Area>/<Area>View.swift Home, Library, Add, Stats, Settings
  Assets.xcassets
android/app/src/main/java/app/quietreading/
  MainActivity.kt                  QuietReadingApp(), AppTab, NavigationBar
  designsystem/                    Tokens.generated.kt, QsTheme.kt, components/
  feature/Screens.kt               all screens for now; split into feature/<area>/ as they grow
android/app/src/main/res/          drawable (icons), values (strings, themes)
```
- One feature = one folder per platform with the same area name (`Features/Library/` ↔ `feature/library/`).
- Build iOS first, then match it on Android.
- Strings: iOS uses `LocalizedStringKey` literals (they can go into a String Catalog later). **Android currently hard-codes UI strings in Kotlin.** New Android text should go in `res/values/strings.xml` and be read with `stringResource(R.string.…)`.
