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

    static var systemBackground: NSColor { .textBackgroundColor }
    static var secondarySystemBackground: NSColor { .windowBackgroundColor }
    static var tertiarySystemBackground: NSColor { .controlBackgroundColor }
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
