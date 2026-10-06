import Foundation
import StatsAgent
import Testing

/// Measures the span step on its own: given the stats call and whether the question compares periods, does the span
/// the model names cover the dates the question asks about?
///
/// Today is fixed at Wednesday 2026-11-18, in UTC, with weeks starting on Monday as the server's do, so that a named
/// month such as August isn't also last month. A comparison is judged by its later span, the one the model names. A
/// question that names no span is right with the default span, the last 30 days.
@Suite(.serialized)
struct SpanTests {
    static let questionsFile = "stats-questions-spans-round-1"
    static let noSpanFile = "stats-questions-no-span-round-1"
    static let subscribersFile = "stats-questions-subscribers-round-1"
    static let visitsFile = "stats-questions-visits-round-1"

    /// Where a question came from, for the report's counts.
    enum Group: CaseIterable {
        case handWritten
        case spans
        case noSpan
        case subscribers
        case visits

        var title: String {
            switch self {
            case .handWritten: "Hand-written"
            case .spans: "Naming spans"
            case .noSpan: "Naming no span"
            case .subscribers: "Subscribers"
            case .visits: "Visits"
            }
        }
    }

    /// A span as the question means it, independent of the spans the model can name.
    enum Span {
        case day(Int, Int, Int)
        /// The week holding this day.
        case week(Int, Int, Int)
        case month(Int, Int)
        case year(Int)
        /// A number of days ending today.
        case days(Int)

        func interval(today: Date, in calendar: Calendar) -> DateInterval? {
            switch self {
            case let .day(year, month, day):
                date(year, month, day, in: calendar).flatMap { calendar.dateInterval(of: .day, for: $0) }
            case let .week(year, month, day):
                date(year, month, day, in: calendar).flatMap { calendar.dateInterval(of: .weekOfYear, for: $0) }
            case let .month(year, month):
                date(year, month, 1, in: calendar).flatMap { calendar.dateInterval(of: .month, for: $0) }
            case let .year(year):
                date(year, 1, 1, in: calendar).flatMap { calendar.dateInterval(of: .year, for: $0) }
            case let .days(count):
                calendar.date(byAdding: .day, value: -(count - 1), to: today)
                    .flatMap { start in
                        calendar.date(byAdding: .day, value: 1, to: today).map { DateInterval(start: start, end: $0) }
                    }
            }
        }

        private func date(_ year: Int, _ month: Int, _ day: Int, in calendar: Calendar) -> Date? {
            calendar.date(from: DateComponents(year: year, month: month, day: day))
        }
    }

    struct Case {
        let label: String
        let question: String
        /// The stats call as the instructions name it, such as "top posts".
        let endpoint: String
        let comparing: Bool
        /// The spans that count as right. Empty when no span the model can name covers the question's dates, so the
        /// case is run but not scored.
        let expected: [Span]
        var group = Group.handWritten
    }

    struct Label {
        let endpoint: String
        let comparing: Bool
        let expected: [Span]

        init(_ endpoint: String, comparing: Bool = false, _ expected: [Span]) {
            self.endpoint = endpoint
            self.comparing = comparing
            self.expected = expected
        }
    }

    /// Questions written directly into the test rather than loaded from a prompt file.
    static let handWritten: [Case] = [
        Case(
            label: "h1",
            question: "which countries do my readers come from last month",
            endpoint: "countries",
            comparing: false,
            expected: [.month(2026, 10)]
        ),
        Case(
            label: "h2",
            question: "which countries did my visitors come from last month",
            endpoint: "countries",
            comparing: false,
            expected: [.month(2026, 10)]
        ),
        Case(
            label: "h3",
            question: "which countries did my visitors come from in august",
            endpoint: "countries",
            comparing: false,
            expected: [.month(2026, 8)]
        ),
        Case(
            label: "h4",
            question: "what was my most successful post in august",
            endpoint: "top posts",
            comparing: false,
            expected: [.month(2026, 8)]
        ),
        Case(
            label: "h5",
            question: "Compare my top posts in august vs september",
            endpoint: "top posts",
            comparing: true,
            expected: [.month(2026, 9)]
        ),
        Case(
            label: "h6",
            question: "What were my most popular posts over the last 90 days?",
            endpoint: "top posts",
            comparing: false,
            expected: [.days(90)]
        )
    ]

    /// Labels for `prompts/raw/stats-questions-spans-round-1.md`, by question number.
    static let labels: [Int: Label] = [
        1: Label("top posts", [.month(2026, 10)]),
        2: Label("countries", [.week(2026, 11, 18)]),
        3: Label("search terms", [.month(2026, 8)]),
        4: Label("referrers", [.days(30)]),
        5: Label("top posts", comparing: true, [.day(2026, 11, 17)]),
        6: Label("top posts", []),
        7: Label("countries", [.year(2025)]),
        8: Label("referrers", []),
        9: Label("top posts", comparing: true, [.month(2026, 11)]),
        10: Label("search terms", [.days(14)]),
        11: Label("referrers", [.days(90)]),
        12: Label("top posts", [.days(365), .year(2025)]),
        13: Label("countries", []),
        14: Label("search terms", []),
        15: Label("referrers", comparing: true, []),
        16: Label("top posts", []),
        17: Label("countries", []),
        18: Label("top posts", []),
        19: Label("referrers", [.day(2026, 11, 18)]),
        20: Label("countries", []),
        21: Label("referrers", comparing: true, [.week(2026, 11, 11)]),
        22: Label("search terms", [.month(2025, 12)]),
        23: Label("top posts", []),
        24: Label("countries", []),
        25: Label("top posts", []),
        26: Label("referrers", [.day(2026, 11, 17)]),
        27: Label("top posts", comparing: true, [.week(2026, 11, 18)]),
        28: Label("search terms", []),
        29: Label("countries", [.month(2026, 10)]),
        30: Label("top posts", [.year(2026)])
    ]

    /// Labels for `prompts/raw/stats-questions-no-span-round-1.md`, by question number. "Overall" asks about
    /// all time, which no span covers, and "right now" also accepts today and the last 7 days.
    static let noSpanLabels: [Int: Label] = [
        1: Label("top posts", []),
        2: Label("top posts", [.day(2026, 11, 18), .days(7), .days(30)]),
        3: Label("referrers", [.days(30)]),
        4: Label("referrers", [.days(30)]),
        5: Label("referrers", [.days(30)]),
        6: Label("countries", [.days(30)]),
        7: Label("cities", [.days(30)]),
        8: Label("countries", [.days(30)]),
        9: Label("search terms", [.days(30)]),
        10: Label("search terms", [.days(30)]),
        11: Label("clicks", [.days(30)]),
        12: Label("clicks", [.days(30)]),
        13: Label("browsers", [.days(30)]),
        14: Label("browsers", [.days(30)]),
        15: Label("platforms", [.days(30)]),
        16: Label("screen sizes", [.days(30)]),
        17: Label("screen sizes", [.days(30)]),
        18: Label("top posts", [.days(30)]),
        19: Label("clicks", [.days(30)]),
        20: Label("countries", [.days(30)])
    ]

    /// Labels for `prompts/raw/stats-questions-subscribers-round-1.md`, by question number. Questions about a
    /// quarter, six months, all time, or the time since a post or a newsletter aren't scored. "Right now" also accepts
    /// the last 7 and 30 days, and "recently" the last 7, 30 and 90.
    static let subscriberLabels: [Int: Label] = [
        1: Label("subscribers", [.day(2026, 11, 18), .days(7), .days(30)]),
        2: Label("subscribers", [.month(2026, 11), .days(30)]),
        3: Label("subscribers", comparing: true, [.week(2026, 11, 18)]),
        4: Label("subscribers", [.days(365), .year(2025)]),
        5: Label("subscribers", [.day(2026, 11, 17)]),
        6: Label("subscribers", comparing: true, []),
        7: Label("subscribers", []),
        8: Label("subscribers", [.month(2026, 11)]),
        9: Label("subscribers", [.year(2026)]),
        10: Label("subscribers", [.day(2026, 11, 18)]),
        11: Label("subscribers", [.days(30)]),
        12: Label("subscribers", comparing: true, [.month(2026, 11)]),
        13: Label("subscribers", []),
        14: Label("subscribers", []),
        15: Label("subscribers", []),
        16: Label("subscribers", []),
        17: Label("subscribers", []),
        18: Label("subscribers", [.year(2026)]),
        19: Label("subscribers", [.days(90)]),
        20: Label("subscribers", [.days(7), .days(30), .days(90)])
    ]

    /// Labels for `prompts/raw/stats-questions-visits-round-1.md`, by question number. Questions about a
    /// single post, all time, a quarter, a holiday weekend, or the time since an event aren't scored, nor is the one
    /// about unreplied comments. "Overnight" accepts today and yesterday, and "lately" the last 7, 30 and 90 days.
    static let visitsLabels: [Int: Label] = [
        1: Label("visits", [.day(2026, 11, 18)]),
        2: Label("visits", [.month(2026, 11)]),
        3: Label("visits", [.day(2026, 11, 17)]),
        4: Label("visits", comparing: true, [.week(2026, 11, 18)]),
        5: Label("visits", []),
        6: Label("visits", [.days(7)]),
        7: Label("visits", [.year(2026)]),
        8: Label("visits", comparing: true, [.month(2026, 11)]),
        9: Label("visits", [.day(2026, 11, 18), .day(2026, 11, 17)]),
        10: Label("visits", []),
        11: Label("visits", []),
        12: Label("visits", []),
        13: Label("visits", [.days(14)]),
        14: Label("visits", [.month(2026, 10)]),
        15: Label("visits", []),
        16: Label("visits", [.days(7), .days(30), .days(90)]),
        17: Label("visits", []),
        18: Label("visits", [.week(2026, 11, 11)]),
        19: Label("visits", comparing: true, [.day(2026, 11, 18)]),
        20: Label("visits", []),
        21: Label("visits", []),
        22: Label("visits", []),
        23: Label("visits", comparing: true, [.month(2026, 9)]),
        24: Label("visits", []),
        25: Label("visits", [])
    ]

    static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .gmt
        calendar.firstWeekday = 2
        calendar.minimumDaysInFirstWeek = 4
        return calendar
    }()

    static func cases() throws -> [Case] {
        try handWritten
            + load(questionsFile, labels: labels, prefix: "s", group: .spans)
            + load(noSpanFile, labels: noSpanLabels, prefix: "n", group: .noSpan)
            + load(subscribersFile, labels: subscriberLabels, prefix: "u", group: .subscribers)
            + load(visitsFile, labels: visitsLabels, prefix: "v", group: .visits)
    }

    private static func load(_ file: String, labels: [Int: Label], prefix: String, group: Group) throws -> [Case] {
        try StatsQuestionCases.load(file)
            .map { number, question in
                let label = try #require(labels[number], "No label for question \(number) of \(file)")
                return Case(
                    label: "\(prefix)\(number)",
                    question: question,
                    endpoint: label.endpoint,
                    comparing: label.comparing,
                    expected: label.expected,
                    group: group
                )
            }
    }

    /// Writes `results/spans.txt` and records an issue for every scored case whose span is wrong.
    @Test func spans() async throws {
        let calendar = Self.calendar
        let now = try #require(calendar.date(from: DateComponents(year: 2026, month: 11, day: 18, hour: 12)))
        let today = calendar.startOfDay(for: now)
        let agent = ParameterAgent(currentDate: now, timeZone: calendar.timeZone)
        let cases = try Self.cases()
        var rows: [String] = []
        var scored: [Group: Int] = [:]
        var right: [Group: Int] = [:]
        let clock = ContinuousClock()
        let start = clock.now
        for testCase in cases {
            let expected = testCase.expected.compactMap { $0.interval(today: today, in: calendar) }
            let answer: String
            let isRight: Bool
            do {
                let params = try await agent.spanParams(
                    for: testCase.question,
                    endpoint: testCase.endpoint,
                    comparingPeriods: testCase.comparing
                )
                let interval = params.periods(today: now, calendar: calendar).interval(in: calendar)
                answer = "\(Self.describe(params)) → \(interval.map { Self.describe($0) } ?? "no dates")"
                isRight = interval.map { expected.contains($0) } ?? false
            } catch {
                answer = "error: \(error)"
                isRight = false
            }
            let mark: String
            if expected.isEmpty {
                mark = "    "
            } else {
                mark = isRight ? "ok  " : "MISS"
                scored[testCase.group, default: 0] += 1
                right[testCase.group, default: 0] += isRight ? 1 : 0
                if !isRight {
                    Issue.record("\(testCase.label): \"\(testCase.question)\" → \(answer)")
                }
            }
            let expectedText =
                expected.isEmpty ? "not scored" : expected.map { Self.describe($0) }.joined(separator: " or ")
            rows.append(
                "\(mark)  \(testCase.label) [\(testCase.endpoint)\(testCase.comparing ? ", comparing" : "")]"
                    + " \"\(testCase.question)\"\n        → \(answer) (expected \(expectedText))"
            )
        }
        let seconds = (clock.now - start).components.seconds
        let totalScored = scored.values.reduce(0, +)
        let groupLines = Group.allCases.map { group in
            "  \(group.title): \(right[group, default: 0])/\(scored[group, default: 0])"
        }

        let report = """
            Spans: one model call fills GenerableSpanParams for each question, given the stats call and
            whether the question compares periods, and the span's dates are worked out in code. Today is 2026-11-18,
            in UTC, with weeks starting on Monday. A comparison is judged by its later span, and a question naming no
            span by the default span, the last 30 days.
            Hand-written questions, then questions\(promptsSource(Self.questionsFile)), then
            questions\(promptsSource(Self.noSpanFile)), then
            questions\(promptsSource(Self.subscribersFile)), then
            questions\(promptsSource(Self.visitsFile)). Greedy sampling.
            \(ProcessInfo.processInfo.operatingSystemVersionString)

            Right: \(right.values.reduce(0, +))/\(totalScored)
            \(groupLines.joined(separator: "\n"))
            Not scored, no span the model can name covers them: \(cases.count - totalScored)
            Time: \(seconds) s for \(cases.count) calls

            \(rows.joined(separator: "\n"))

            """
        try writeResults(report, to: "spans.txt")
    }

    /// The span and the fields the model filled in.
    static func describe(_ params: GenerableSpanParams) -> String {
        var fields: [String] = []
        if let year = params.year {
            fields.append("year: \(year)")
        }
        if let days = params.days {
            fields.append("days: \(days)")
        }
        return fields.isEmpty ? "\(params.span)" : "\(params.span) (\(fields.joined(separator: ", ")))"
    }

    /// The first and last day of `interval`.
    static func describe(_ interval: DateInterval) -> String {
        let lastDay = calendar.date(byAdding: .day, value: -1, to: interval.end) ?? interval.end
        return "\(day(interval.start))…\(day(lastDay))"
    }

    private static func day(_ date: Date) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", components.year ?? 0, components.month ?? 0, components.day ?? 0)
    }
}
