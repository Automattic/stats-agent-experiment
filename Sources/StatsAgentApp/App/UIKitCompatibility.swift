import AppKit
import SwiftUI

// The views in `JetpackStats/` are copied from the WordPress iOS app. These stand in for the UIKit and WordPressShared
// names they use, so the copies build on macOS with few changes.

typealias UIColor = NSColor

extension NSColor {
    /// `light` in a light appearance, `dark` in a dark one.
    convenience init(light: NSColor, dark: NSColor) {
        self.init(name: nil) { appearance in
            appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua ? dark : light
        }
    }

    // The backgrounds take iOS's values. macOS's window and text backgrounds are too close to each other to stand in
    // for them: the stats cards and the page behind them would look the same.
    static var systemBackground: NSColor {
        NSColor(light: .white, dark: .black)
    }
    static var secondarySystemBackground: NSColor {
        NSColor(
            light: NSColor(srgbRed: 0.949, green: 0.949, blue: 0.969, alpha: 1),
            dark: NSColor(srgbRed: 0.110, green: 0.110, blue: 0.118, alpha: 1)
        )
    }
    static var tertiarySystemBackground: NSColor {
        NSColor(light: .white, dark: NSColor(srgbRed: 0.173, green: 0.173, blue: 0.180, alpha: 1))
    }
    static var systemGroupedBackground: NSColor { .windowBackgroundColor }
    static var separator: NSColor { .separatorColor }
    static var opaqueSeparator: NSColor { .gridColor }
}

extension Color {
    init(uiColor: NSColor) {
        self.init(nsColor: uiColor)
    }
}

/// Returns `value`, the English text. The iOS app looks the text up in its own bundle.
func AppLocalizedString(_ key: String, tableName: String? = nil, value: String? = nil, comment: String) -> String {
    value ?? key
}
