import AppKit
import SwiftUI

/// Saves pictures of the app to `.build/screenshots/` in the directory the app starts in, which git ignores.
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
