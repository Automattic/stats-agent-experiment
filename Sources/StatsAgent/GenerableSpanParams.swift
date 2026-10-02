import FoundationModels

/// The span of time a stats question asks about, in a form the on-device model can generate, for visits, subscribers
/// and the stats calls that rank items, such as top posts. The model names a span, and code works out its dates. The
/// maximum number of items applies to the ranking calls alone.
@Generable
public struct GenerableSpanParams: Equatable, Sendable {
    @Guide(description: "The span of time the question asks about.")
    public var span: StatsSpan

    @Guide(description: "The year the question names, when it names one.")
    public var year: Int?

    @Guide(description: "The number of days, when the span is a number of recent days.")
    public var days: Int?

    @Guide(description: "The maximum number of items to return.")
    public var max: Int?

    public init(span: StatsSpan, year: Int?, days: Int?, max: Int?) {
        self.span = span
        self.year = year
        self.days = days
        self.max = max
    }
}

/// Whether a question names a time, decided in a call of its own.
@Generable
public struct GenerableTimeMention: Equatable, Sendable {
    @Guide(
        description: "Whether the question names a time or a span of time, such as a day, a week, a month, a year or a"
            + " number of days."
    )
    public var namesTime: Bool
}

/// A span of time a question can ask about. Each month is a span of its own, and a question that names no span gets
/// ``StatsSpan/noSpanNamed``, for code to choose one.
@Generable
public enum StatsSpan: Equatable, Sendable {
    case today
    case yesterday
    case thisWeek
    case lastWeek
    case thisMonth
    case lastMonth
    case january
    case february
    case march
    case april
    case may
    case june
    case july
    case august
    case september
    case october
    case november
    case december
    case thisYear
    case lastYear
    case namedYear
    case last7Days
    case last30Days
    case last90Days
    case recentDays
    case noSpanNamed

    /// The month's number, 1 to 12, when the span is a month named by its name.
    public var month: Int? {
        switch self {
        case .january: 1
        case .february: 2
        case .march: 3
        case .april: 4
        case .may: 5
        case .june: 6
        case .july: 7
        case .august: 8
        case .september: 9
        case .october: 10
        case .november: 11
        case .december: 12
        default: nil
        }
    }
}
