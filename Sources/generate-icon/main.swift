import AppKit
import SwiftUI

// `generate-icon <iconset>` draws the app's icon at every size an icon set holds, as PNGs in the `.iconset` folder,
// which `make icon` makes into `Sources/StatsAgentApp/AppIcon.icns`. The icon is a tile in WordPress blue with a white
// line chart rising to a sparkle, drawn on the 1024-point canvas of macOS icons, whose tile is 824 points wide.

/// ColorStudio's Blue 40 and Blue 70, either side of the app's own WordPress blue, Blue 50.
let lightBlue = Color(red: 84 / 255, green: 111 / 255, blue: 243 / 255)
let darkBlue = Color(red: 29 / 255, green: 53 / 255, blue: 180 / 255)

struct AppIcon: View {
    /// The size the icon is drawn at, in pixels, which keeps the line at least 1.5 pixels wide.
    let pixels: Int

    static let tile = CGRect(x: 100, y: 100, width: 824, height: 824)
    /// The line's points, as fractions of the tile's width and height from its top left.
    static let points = [(0.2, 0.73), (0.35, 0.59), (0.48, 0.66), (0.64, 0.45)]

    var body: some View {
        Canvas { context, _ in
            let tile = Path(roundedRect: Self.tile, cornerRadius: 185, style: .continuous)
            var shadowed = context
            shadowed.addFilter(.shadow(color: .black.opacity(0.3), radius: 12, x: 0, y: 10))
            shadowed.fill(
                tile,
                with: .linearGradient(
                    Gradient(colors: [lightBlue, darkBlue]),
                    startPoint: CGPoint(x: Self.tile.midX, y: Self.tile.minY),
                    endPoint: CGPoint(x: Self.tile.midX, y: Self.tile.maxY)
                )
            )

            let points = Self.points.map(Self.point)
            let lineWidth = max(52, 1.5 * 1024 / Double(pixels))
            var line = Path()
            line.addLines(points)
            context.stroke(
                line,
                with: .color(.white),
                style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round)
            )
            // The sparkle carries on from the line's last segment, clear of its end.
            let sparkleRadius = 110.0
            let last = points[points.count - 1]
            let before = points[points.count - 2]
            let length = hypot(last.x - before.x, last.y - before.y)
            let gap = 0.7 * sparkleRadius + lineWidth / 2
            let sparkle = CGPoint(
                x: last.x + (last.x - before.x) * gap / length,
                y: last.y + (last.y - before.y) * gap / length
            )
            context.fill(Self.sparkle(at: sparkle, radius: sparkleRadius), with: .color(.white))
        }
        .frame(width: 1024, height: 1024)
    }

    static func point(_ fraction: (Double, Double)) -> CGPoint {
        CGPoint(x: tile.minX + fraction.0 * tile.width, y: tile.minY + fraction.1 * tile.height)
    }

    /// A four-pointed star with curved sides, its points `radius` from `center`.
    static func sparkle(at center: CGPoint, radius: Double) -> Path {
        let pinch = radius * 0.16
        let tips = [(0.0, -1.0), (1.0, 0.0), (0.0, 1.0), (-1.0, 0.0)]
            .map { CGPoint(x: center.x + $0.0 * radius, y: center.y + $0.1 * radius) }
        var path = Path()
        path.move(to: tips[0])
        for index in tips.indices {
            let from = tips[index]
            let to = tips[(index + 1) % tips.count]
            // Between two tips, the side curves in toward the centre.
            let control = CGPoint(
                x: center.x + (from.x + to.x - 2 * center.x) * pinch / radius,
                y: center.y + (from.y + to.y - 2 * center.y) * pinch / radius
            )
            path.addQuadCurve(to: to, control: control)
        }
        path.closeSubpath()
        return path
    }
}

/// The icon set's PNGs: each size in points, at 1x and 2x.
let sizes = [16, 32, 128, 256, 512]

let arguments = CommandLine.arguments
guard arguments.count == 2 else {
    FileHandle.standardError.write(Data("Usage: generate-icon <iconset>\n".utf8))
    exit(1)
}
let folder = URL(filePath: arguments[1], directoryHint: .isDirectory)

do {
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    for size in sizes {
        for scale in [1, 2] {
            let pixels = size * scale
            let renderer = ImageRenderer(content: AppIcon(pixels: pixels))
            renderer.scale = Double(pixels) / 1024
            guard let image = renderer.cgImage,
                let png = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:])
            else {
                throw CocoaError(.fileWriteUnknown)
            }
            let name = "icon_\(size)x\(size)\(scale == 2 ? "@2x" : "").png"
            try png.write(to: folder.appending(path: name))
        }
    }
} catch {
    FileHandle.standardError.write(Data("generate-icon: \(error)\n".utf8))
    exit(1)
}
