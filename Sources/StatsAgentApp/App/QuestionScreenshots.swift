#if DEBUG
import AppKit
import StatsAgent
import StatsAgentDatabase
import SwiftUI

/// File → Take Screenshots… in debug builds, such as `make run`'s: asks each question in a text file, one a line, on
/// the site logged in to, and saves pictures of the window with each answer, in light and dark, to a folder beside the
/// file. A question with several cards gets a picture of each. `answers.txt` in the folder lists what each question
/// got. The questions are recorded in a database in memory, so the app's own stays as it is.
@MainActor
enum QuestionScreenshots {
    private static var isRunning = false

    /// Asks for the questions file, takes the screenshots, and shows the folder in the Finder, or says why it couldn't.
    static func start(account: Account) {
        guard !isRunning else {
            return
        }
        let panel = NSOpenPanel()
        panel.message = "Choose a text file with one question a line."
        panel.allowedContentTypes = [.plainText]
        guard panel.runModal() == .OK, let file = panel.url else {
            return
        }
        isRunning = true
        Task {
            defer { isRunning = false }
            do {
                let folder = try await run(questionsIn: file, account: account)
                NSWorkspace.shared.activateFileViewerSelecting([folder])
            } catch {
                let alert = NSAlert()
                alert.messageText = "Couldn't take the screenshots"
                alert.informativeText = Answer.message(for: error)
                alert.runModal()
            }
        }
    }

    /// Asks the questions in `file` and returns the folder the pictures are in.
    private static func run(questionsIn file: URL, account: Account) async throws -> URL {
        guard let site = account.site, let stats = account.stats else {
            throw Screenshots.Failure(errorDescription: "Log in and pick a site first.")
        }
        let questions = try String(contentsOf: file, encoding: .utf8)
            .split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        let folder = file.deletingLastPathComponent()
            .appending(path: "\(file.deletingPathExtension().lastPathComponent)-\(Screenshots.timestamp)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let recorder = Recorder(database: Result { try AppDatabase.inMemory() })
        let context = site.timeZone.map { StatsContext(timeZone: $0) } ?? .demo
        var lines: [String] = []
        for (index, question) in questions.enumerated() {
            let number = String(format: "%02d", index + 1)
            let answer = Answer(question: question)
            let questionRecorder = await recorder.start(answer, site: site, stats: stats)
            await answer.run(stats: .success(stats), context: context, recorder: questionRecorder)
            lines += describe(answer, number: number)
            try (lines.joined(separator: "\n") + "\n")
                .write(to: folder.appending(path: "answers.txt"), atomically: true, encoding: .utf8)
            for page in 0..<max(answer.cards.count, 1) {
                answer.showCard(at: page)
                let name = answer.cards.count > 1 ? "\(number)-card-\(page + 1)" : number
                for (suffix, appearance) in [("light", NSAppearance.Name.aqua), ("dark", .darkAqua)] {
                    let window = RootView(
                        account: Account(previewToken: "screenshots", site: site),
                        questions: Questions(recorder: recorder, answers: [answer], isAsking: false)
                    )
                    try await Screenshots.saveWindow(
                        AnyView(window),
                        size: Previews.size,
                        appearance: appearance,
                        to: folder.appending(path: "\(name)-\(suffix).png")
                    )
                }
            }
        }
        return folder
    }

    /// The question, how it ended, its cards and its answer in words, such as `01. How many views did I get today?`.
    private static func describe(_ answer: Answer, number: String) -> [String] {
        var lines = ["\(number). \(answer.question)", "    Outcome: \(answer.outcome?.rawValue ?? "unfinished")"]
        if let error = answer.error {
            lines.append("    Error: \(error)")
        }
        for (index, card) in answer.cards.enumerated() {
            lines.append("    Card \(index + 1): \(card.title) (\(card.path.joined(separator: " › ")))")
        }
        if let written = answer.written {
            lines.append("    Answer: \(written)")
        }
        return lines + [""]
    }
}

/// File → Take Screenshots…, after the import and export items, in debug builds.
struct ScreenshotCommands: Commands {
    /// The account the questions are asked on, read when the item is chosen.
    let account: @MainActor () -> Account

    var body: some Commands {
        CommandGroup(after: .importExport) {
            Button("Take Screenshots…") {
                QuestionScreenshots.start(account: account())
            }
        }
    }
}
#endif
