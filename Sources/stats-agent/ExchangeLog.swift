import Foundation
import StatsAgent

/// One prompt and everything that happened to it, as logged.
struct Exchange: Codable {
    struct Attempt: Codable {
        let area: String
        let areaOptions: Int
        let areaSeconds: Double
        /// `none_of_these` when the model backed out of the area.
        let leaf: String
        let leafOptions: Int
        let leafSeconds: Double

        init(_ attempt: CatalogNavigator.Attempt) {
            area = attempt.branch.id
            areaOptions = attempt.branchStep.optionCount
            areaSeconds = attempt.branchStep.duration.seconds
            leaf = attempt.leafStep.choice
            leafOptions = attempt.leafStep.optionCount
            leafSeconds = attempt.leafStep.duration.seconds
        }
    }

    var date = Date()
    var system = ProcessInfo.processInfo.operatingSystemVersionString
    let prompt: String
    var attempts: [Attempt] = []
    /// The leaf reached, or nil when every attempt ended in "none of these" or an error.
    var result: String?
    var parameters: [String: String]?
    var parameterSeconds: Double?
    var totalSeconds: Double?
    /// When the person answered: `answers` (the result would answer the question), `relevant` (the right place, but
    /// it wouldn't answer it) or `wrong`. Some logs hold `right` or `wrong` alone, from a prompt without `relevant`.
    var verdict: String?
    /// What the person expected instead, in their own words.
    var expected: String?
    var error: String?

    init(prompt: String) {
        self.prompt = prompt
    }
}

/// Appends exchanges to a JSON Lines file, one exchange per line.
struct ExchangeLog {
    let url: URL

    /// `sessions/<yyyy-MM-dd>.jsonl` in the current directory.
    static func forToday() -> ExchangeLog {
        let day = Date().formatted(Date.ISO8601FormatStyle(timeZone: .current).year().month().day())
        let directory = URL(filePath: FileManager.default.currentDirectoryPath).appending(path: "sessions")
        return ExchangeLog(url: directory.appending(path: "\(day).jsonl"))
    }

    func append(_ exchange: Exchange) throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        let line = try encoder.encode(exchange) + Data("\n".utf8)
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        if !FileManager.default.fileExists(atPath: url.path(percentEncoded: false)) {
            try Data().write(to: url)
        }
        let handle = try FileHandle(forWritingTo: url)
        defer { try? handle.close() }
        try handle.seekToEnd()
        try handle.write(contentsOf: line)
    }
}
