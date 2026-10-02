import Foundation
import StatsAgent

/// The 1-based position of the option with `id`, or 0 when it isn't in the list.
func position(of id: String, in options: [OptionSelector.Option]) -> Int {
    options.firstIndex { $0.id == id }.map { $0 + 1 } ?? 0
}

/// Right-aligns `value` in a column `width` characters wide.
func pad(_ value: some CustomStringConvertible, _ width: Int) -> String {
    let text = value.description
    return String(repeating: " ", count: max(0, width - text.count)) + text
}

/// ` from prompts/raw/<name>.md` for report headers, or empty when `name` is nil.
func promptsSource(_ name: String?) -> String {
    name.map { " from prompts/raw/\($0).md" } ?? ""
}

/// The package root, found from this source file's location.
func packageRoot(filePath: String = #filePath) -> URL {
    URL(filePath: filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
}

/// Writes `report` to `results/<fileName>` at the package root. `fileName` may include subdirectories.
func writeResults(_ report: String, to fileName: String) throws {
    let file = packageRoot().appending(path: "results").appending(path: fileName)
    try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
    try report.write(to: file, atomically: true, encoding: .utf8)
}

/// A small seeded generator so shuffles are the same on every run.
struct SplitMix64: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}
