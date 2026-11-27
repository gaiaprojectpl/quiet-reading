import CoreText
import Foundation

/// Registers the bundled heading fonts (Resources/Fonts, all SIL OFL) for this process.
/// Call once at launch – the app and, later, the widget extension each need to call it.
/// Done in code because the target generates its Info.plist (no UIAppFonts key).
nonisolated enum QsFonts {
    static func register(bundle: Bundle = .main) {
        guard let urls = bundle.urls(forResourcesWithExtension: "ttf", subdirectory: nil), !urls.isEmpty else {
            assertionFailure("No bundled fonts found")
            return
        }
        CTFontManagerRegisterFontURLs(urls as CFArray, .process, true, nil)
    }
}
