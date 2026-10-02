import Foundation
import StatsAgent
import Testing

/// Loads prompt files from `prompts/raw`.
///
/// A file lists numbered originals, each followed by `A:` and `B:` versions. A version gets the acceptable leaves of
/// the `SelectionCases.all` prompt with the same number, and a label such as `1A`. The originals themselves are
/// skipped, since `SelectionCases.all` already covers them.
enum PromptSets {
    struct FormatError: Error, CustomStringConvertible {
        let line: String
        var description: String { "Unexpected line in prompt file: \(line)" }
    }

    /// The prompt file named by the `PROMPTS` environment variable, for example `paraphrases-round-1`.
    static var requestedName: String? {
        ProcessInfo.processInfo.environment["PROMPTS"]
    }

    static func load(_ name: String) throws -> [SelectionCase] {
        let url = packageRoot().appending(path: "prompts/raw/\(name).md")
        let text = try String(contentsOf: url, encoding: .utf8)
        var cases: [SelectionCase] = []
        var number = 0
        for line in text.split(separator: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if let match = trimmed.firstMatch(of: /^(\d+)\.\s/) {
                guard let parsed = Int(match.1), SelectionCases.all.indices.contains(parsed - 1) else {
                    throw FormatError(line: trimmed)
                }
                number = parsed
            } else if let match = trimmed.firstMatch(of: /^([AB]): (.+)$/), number > 0 {
                cases.append(
                    SelectionCase(
                        prompt: String(match.2),
                        acceptable: SelectionCases.all[number - 1].acceptable,
                        label: "\(number)\(match.1)"
                    )
                )
            } else if !trimmed.isEmpty {
                throw FormatError(line: trimmed)
            }
        }
        return cases
    }
}

/// Runs the selection experiments on the prompt file named by `PROMPTS`, writing results to `results/<name>/`:
///
///     PROMPTS=paraphrases-round-1 swift test --filter PromptSetTests
///
/// Flat selection runs only at the full catalog size. The suite is skipped when `PROMPTS` isn't set.
@Suite(.serialized, .enabled(if: PromptSets.requestedName != nil))
struct PromptSetTests {
    @Test func flatSelectionOverWholeCatalog() async throws {
        let name = try #require(PromptSets.requestedName)
        try await FlatSelectionTests.run(
            cases: PromptSets.load(name),
            sizes: [Catalog.leaves.count],
            promptsName: name,
            resultsFile: "\(name)/flat-selection.txt"
        )
    }

    @Test func pyramidSelection() async throws {
        let name = try #require(PromptSets.requestedName)
        try await PyramidSelectionTests.run(
            cases: PromptSets.load(name),
            promptsName: name,
            resultsFile: "\(name)/pyramid-selection.txt"
        )
    }

    @Test func pyramidWithBacktracking() async throws {
        let name = try #require(PromptSets.requestedName)
        try await BacktrackingSelectionTests.run(
            cases: PromptSets.load(name),
            promptsName: name,
            resultsFile: "\(name)/pyramid-backtracking.txt"
        )
    }
}
