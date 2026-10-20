import AppKit
import SwiftUI

/// Saves pictures of the app: of a view, to `.build/screenshots/` in the directory the app starts in, which git
/// ignores, and of a whole window drawn off screen, to a file given.
@MainActor
enum Screenshots {
    struct Failure: LocalizedError {
        let errorDescription: String?
    }

    static var directory: URL {
        URL(filePath: FileManager.default.currentDirectoryPath).appending(path: ".build/screenshots")
    }

    /// A name for files saved now, such as `2026-09-26-12.27.18`.
    static var timestamp: String {
        Date.now.formatted(
            .verbatim(
                "\(year: .defaultDigits)-\(month: .twoDigits)-\(day: .twoDigits)-\(hour: .twoDigits(clock: .twentyFourHour, hourCycle: .zeroBased)).\(minute: .twoDigits).\(second: .twoDigits)",
                timeZone: .current,
                calendar: .current
            )
        )
    }

    /// Renders `view` off screen at `size` and saves it as a PNG in `directory` under `name`.
    static func save(_ view: some View, size: CGSize, to directory: URL, name: String) throws -> URL {
        let renderer = ImageRenderer(content: view.frame(width: size.width, height: size.height))
        renderer.scale = 2
        let png = renderer.nsImage
            .flatMap { $0.tiffRepresentation }
            .flatMap { NSBitmapImageRep(data: $0) }
            .flatMap { $0.representation(using: .png, properties: [:]) }
        return try write(png, to: directory, name: name)
    }

    /// Draws `view` in a window off screen at `size`, title bar and toolbar included, in `appearance`, or alone at
    /// `size` for a sheet, and saves it as a PNG at `file`.
    static func saveWindow(
        _ view: AnyView,
        size: CGSize,
        isSheet: Bool = false,
        appearance: NSAppearance.Name,
        to file: URL
    ) async throws {
        let hosting = NSHostingView(rootView: view)
        hosting.sceneBridgingOptions = [.title, .toolbars]
        // A full-size content view, as SwiftUI's own windows have: the content runs under the title bar and the toolbar,
        // and keeps clear of them only through its safe area.
        let window = NSWindow(
            contentRect: CGRect(origin: CGPoint(x: -20_000, y: -20_000), size: size),
            styleMask: isSheet
                ? [.borderless] : [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.isReleasedWhenClosed = false
        window.appearance = NSAppearance(named: appearance)
        window.contentView = hosting
        window.orderFront(nil)
        defer { window.close() }
        // Lets SwiftUI lay out, run the views' tasks and settle their animations.
        try await Task.sleep(for: .seconds(1))
        let frame = hosting.superview ?? hosting
        guard let bitmap = frame.bitmapImageRepForCachingDisplay(in: frame.bounds) else {
            throw Failure(errorDescription: "The window couldn't be drawn.")
        }
        frame.cacheDisplay(in: frame.bounds, to: bitmap)
        guard let png = bitmap.representation(using: .png, properties: [:]) else {
            throw Failure(errorDescription: "The picture couldn't be made into a PNG.")
        }
        try png.write(to: file)
    }

    private static func write(_ png: Data?, to directory: URL, name: String) throws -> URL {
        guard let png else {
            throw Failure(errorDescription: "The picture couldn't be made into a PNG.")
        }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let file = directory.appending(path: name)
        try png.write(to: file)
        return file
    }
}
