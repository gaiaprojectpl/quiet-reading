# Quiet Reading

A calm reading tracker for iPhone (incl. iPhone Duo) and Android, with beautiful Home Screen widgets.

| Folder | What's inside |
|---|---|
| `ios/` | Swift 6 + SwiftUI app, WidgetKit widgets (min iOS 18) |
| `android/` | Kotlin + Jetpack Compose app, Glance widgets (min API 26) |
| `design-tokens/` | `tokens.json` exported from Figma (App themes, Spacing, Foundations) |
| `tools/` | `generate_tokens.py` turns tokens into Swift and Kotlin |
| `docs/` | Setup and decisions |

Design: [Figma](https://www.figma.com/design/dw4Stk6aD7oiLaBANzIOCR) · bundle ID / package `app.quietreading`.

## Design tokens
Never hard-code colours, radii or spacing. After a token change in Figma, update `design-tokens/tokens.json`, then run:

```
python3 tools/generate_tokens.py
```

Six theme modes: Peach & Sage (free), Clay & Cream, Blush & Ivory, Lavender & Mist (Plus), Night (dark, free), High contrast (free). All pass WCAG AA.

## Secrets
Copy `Secrets.example.env` to `Secrets.env` and fill in the keys. `Secrets.env` is git-ignored.
