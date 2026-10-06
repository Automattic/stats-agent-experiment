import StatsAgentDatabase
import SwiftUI
import UniformTypeIdentifiers

/// The Export Data sheet: which questions go in, by when they were asked and the site they're about, and what goes in
/// with them. What always goes in shows as checked boxes that can't be unchecked; feedback is checked to start, and the
/// sites' names, addresses and IDs and WordPress.com's responses aren't. Export… saves a JSON file, or a zip with the
/// responses, where the person chooses.
struct ExportView: View {
    let database: AppDatabase?
    @Environment(\.dismiss) private var dismiss
    @State private var range = ExportRange.allTime
    /// The sites asked about in `range`, with their counts.
    @State private var sites: [ExportableSite]
    /// The sites unchecked, so a site that comes into the range starts checked.
    @State private var excludedSites: Set<Int64> = []
    @State private var isSitesExpanded = true
    @State private var feedback = true
    @State private var siteDetails = false
    @State private var responses = false
    /// The export made, while the save panel is open.
    @State private var document: ExportDocument?
    @State private var error: String?

    static let size = CGSize(width: 600, height: 720)

    init(database: AppDatabase?) {
        self.database = database
        _sites = State(initialValue: [])
    }

    /// The sheet as `--previews` draws it: made-up `sites`, and no database.
    init(previewing sites: [ExportableSite]) {
        database = nil
        _sites = State(initialValue: sites)
    }

    var body: some View {
        VStack(spacing: 0) {
            Form {
                Section {
                    Picker("Questions from", selection: $range) {
                        ForEach(ExportRange.allCases, id: \.self) { range in
                            Text(range.title).tag(range)
                        }
                    }
                } header: {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Export Data")
                            .font(.title2.weight(.semibold))
                            .foregroundStyle(.primary)
                        Text(
                            "Choose what to share. Nothing leaves this Mac until you save the file and send it yourself."
                        )
                        .font(.body)
                    }
                    .padding(.bottom, 8)
                }
                Section(isExpanded: $isSitesExpanded) {
                    if sites.isEmpty {
                        Text("No questions were asked in this time.")
                            .foregroundStyle(.secondary)
                    }
                    ForEach(sites, id: \.id) { site in
                        Toggle(isOn: isChosen(site)) {
                            Text(site.name)
                            Text("\(Self.host(of: site.url)) · \(Self.count(site.questions, "question"))")
                        }
                    }
                } header: {
                    Text("Sites (\(chosenSites.count) of \(sites.count))")
                }
                Section("Always included") {
                    AlwaysIncluded(
                        "Agent interactions",
                        "Your questions and when you asked them, each choice the agent made and the values it filled "
                            + "in, the cards it showed with the dates it asked for, and which cards you looked at."
                    )
                    AlwaysIncluded(
                        "General information",
                        "Your sites' time zones, and the app version, commit and macOS version that answered."
                    )
                }
                Section("Optional") {
                    Toggle(isOn: $feedback) {
                        Text("Feedback")
                        Text(
                            "Your verdict on each answer, the card that answered, your notes, and whether something "
                                + "looked broken."
                        )
                    }
                    Toggle(isOn: $siteDetails) {
                        Text("Site names, addresses and IDs")
                        Text(
                            "Usually not needed, only to debug something on a particular site. Without them, sites are "
                                + "numbered 1, 2, …"
                        )
                    }
                    Toggle(isOn: $responses) {
                        Text("WordPress.com's responses")
                        Text(
                            "Your site's stats as-is from WordPress.com: numbers, post titles, referrers, search terms. "
                                + "Usually not needed; only for debugging, and only if you're comfortable sharing them. "
                                + "The export becomes a .zip."
                        )
                    }
                }
            }
            .formStyle(.grouped)
            .toggleStyle(.checkbox)
            Divider()
            HStack(spacing: 12) {
                if let error {
                    Text(error)
                        .foregroundStyle(.red)
                        .textSelection(.enabled)
                } else {
                    Text(summary)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Cancel", role: .cancel) {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
                Button("Export…", action: export)
                    .keyboardShortcut(.defaultAction)
                    .disabled(chosenQuestions == 0)
            }
            .padding(20)
        }
        .frame(width: Self.size.width, height: Self.size.height)
        .task(id: range) {
            await loadSites()
        }
        .fileExporter(
            isPresented: Binding(get: { document != nil }, set: { if !$0 { document = nil } }),
            document: document,
            contentType: document?.contentType ?? .json,
            defaultFilename: document?.name
        ) { result in
            switch result {
            case .success:
                dismiss()
            case .failure(let failure):
                error = "Couldn't save the export: \(Answer.message(for: failure))"
            }
        }
    }

    private var chosenSites: [ExportableSite] {
        sites.filter { !excludedSites.contains($0.id) }
    }

    private var chosenQuestions: Int {
        chosenSites.map(\.questions).reduce(0, +)
    }

    /// How many questions go in, and how many with feedback when it's included.
    private var summary: String {
        guard chosenQuestions > 0 else {
            return "No questions to export"
        }
        let questions = Self.count(chosenQuestions, "question")
        guard feedback else {
            return questions
        }
        return "\(questions), \(chosenSites.map(\.questionsWithFeedback).reduce(0, +)) with feedback"
    }

    private func isChosen(_ site: ExportableSite) -> Binding<Bool> {
        Binding {
            !excludedSites.contains(site.id)
        } set: { isChosen in
            if isChosen {
                excludedSites.remove(site.id)
            } else {
                excludedSites.insert(site.id)
            }
        }
    }

    private func loadSites() async {
        guard let database else {
            return
        }
        do {
            sites = try await database.exportableSites(since: range.since(.now))
        } catch {
            self.error = "Couldn't read the database: \(Answer.message(for: error))"
        }
    }

    private func export() {
        guard let database else {
            return
        }
        error = nil
        let options = ExportOptions(
            since: range.since(.now),
            siteIDs: Set(chosenSites.map(\.id)),
            included: ExportV1.Included(feedback: feedback, siteDetails: siteDetails, responses: responses)
        )
        let name = "Stats agent export \(Date.now.formatted(.iso8601.year().month().day()))"
        Task {
            do {
                let export = try await database.export(options, at: .now)
                let file = try await Task.detached { try export.file(named: name) }.value
                document = ExportDocument(file: file, name: name)
            } catch {
                self.error = "Couldn't make the export: \(Answer.message(for: error))"
            }
        }
    }

    /// The host of `url`, or `url` itself when it has none.
    private static func host(of url: String) -> String {
        URL(string: url)?.host() ?? url
    }

    private static func count(_ count: Int, _ noun: String) -> String {
        "\(count) \(noun)\(count == 1 ? "" : "s")"
    }
}

/// A part of the export that can't be left out: a checked box that can't be unchecked, with its title and subtitle as
/// readable as the other rows'.
private struct AlwaysIncluded: View {
    let title: String
    let subtitle: String

    init(_ title: String, _ subtitle: String) {
        self.title = title
        self.subtitle = subtitle
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 5) {
            Toggle(title, isOn: .constant(true))
                .labelsHidden()
                .disabled(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

/// How far back the questions in an export go.
enum ExportRange: CaseIterable, Hashable {
    case pastHour
    case pastDay
    case pastWeek
    case pastMonth
    case allTime

    var title: String {
        switch self {
        case .pastHour: "The past hour"
        case .pastDay: "The past day"
        case .pastWeek: "The past week"
        case .pastMonth: "The past month"
        case .allTime: "All time"
        }
    }

    /// When the range starts, counting back from `now`, or nil for all time.
    func since(_ now: Date) -> Date? {
        switch self {
        case .pastHour: now.addingTimeInterval(-3600)
        case .pastDay: Calendar.current.date(byAdding: .day, value: -1, to: now)
        case .pastWeek: Calendar.current.date(byAdding: .day, value: -7, to: now)
        case .pastMonth: Calendar.current.date(byAdding: .month, value: -1, to: now)
        case .allTime: nil
        }
    }
}

/// An export as the save panel writes it: a JSON file, or a zip.
struct ExportDocument: FileDocument {
    static let readableContentTypes: [UTType] = [.json, .zip]

    let file: ExportFile
    /// The file's name, without its extension.
    let name: String

    var contentType: UTType {
        file.pathExtension == "zip" ? .zip : .json
    }

    init(file: ExportFile, name: String) {
        self.file = file
        self.name = name
    }

    /// Exports are only written.
    init(configuration: ReadConfiguration) throws {
        throw CocoaError(.featureUnsupported)
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: file.data)
    }
}

extension FocusedValues {
    /// Opens the Export Data sheet, while the window can export.
    @Entry var exportData: (() -> Void)?
}

/// File → Export Data… (⇧⌘E), in place of the File menu's import and export items, while the window can export.
struct ExportCommands: Commands {
    @FocusedValue(\.exportData) private var exportData

    var body: some Commands {
        CommandGroup(replacing: .importExport) {
            Button("Export Data…") {
                exportData?()
            }
            .keyboardShortcut("e", modifiers: [.command, .shift])
            .disabled(exportData == nil)
        }
    }
}
