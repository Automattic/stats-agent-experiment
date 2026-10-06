import Foundation

/// A request to a stats call that ranks items, as the app makes it, between the model's parameters and the wordpress-rs
/// request.
struct RankingRequest: Equatable, Sendable {
    /// Day, week, month or year.
    var granularity: DateRangeGranularity
    /// `YYYY-MM-DD`, the last period's date, or nil for the server's default: today, in the site's time zone.
    var date: String?
    /// How many periods to add up, ending on `date`.
    var periods: Int
    var maximumItems: Int

    /// The parameters in plain words, for a card's path.
    var summary: String {
        let unit = String(describing: granularity)
        let end = date.map { "ending \($0)" } ?? "ending today"
        return "\(periods) \(unit)\(periods == 1 ? "" : "s"), \(end), top \(maximumItems)"
    }

    /// The parameters as the database records them.
    var logged: [String: String] {
        ["granularity": "\(granularity)", "date": date, "periods": "\(periods)", "maximumItems": "\(maximumItems)"]
            .compactMapValues(\.self)
    }

    /// The span the request covers, from the start of its first period to the end of its last, in `calendar`.
    func interval(in calendar: Calendar) -> DateInterval? {
        let component = granularity.component
        guard let last = lastDate(in: calendar),
            let lastPeriod = calendar.dateInterval(of: component, for: last),
            let start = calendar.date(byAdding: component, value: -(periods - 1), to: lastPeriod.start)
        else {
            return nil
        }
        return DateInterval(start: start, end: lastPeriod.end)
    }

    /// The same request for the span just before this one.
    func previous(in calendar: Calendar) -> RankingRequest? {
        guard let last = lastDate(in: calendar),
            let previousLast = calendar.date(byAdding: granularity.component, value: -periods, to: last)
        else {
            return nil
        }
        var request = self
        request.date = Self.day(previousLast, in: calendar)
        return request
    }

    /// The same span as whole days, for the calls that read the number of periods as a number of days whatever the
    /// period: from the start of the first period to the end of the last one, or to today when that's earlier.
    func inDays(in calendar: Calendar) -> RankingRequest {
        guard granularity != .day,
            let interval = interval(in: calendar),
            let lastPeriodDay = calendar.date(byAdding: .day, value: -1, to: interval.end)
        else {
            return self
        }
        let lastDay = min(lastPeriodDay, calendar.startOfDay(for: .now))
        let days = (calendar.dateComponents([.day], from: interval.start, to: lastDay).day ?? 0) + 1
        var request = self
        request.granularity = .day
        request.periods = max(days, 1)
        request.date = Self.day(lastDay, in: calendar)
        return request
    }

    /// This span as whole days up to today, when today cuts it short, such as this month so far; nil when the span
    /// ends by today.
    func cutAtToday(in calendar: Calendar) -> RankingRequest? {
        guard let interval = interval(in: calendar),
            let tomorrow = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: .now)),
            interval.end > tomorrow
        else {
            return nil
        }
        return inDays(in: calendar)
    }

    /// The first `days` days of this span, as whole days.
    func firstDays(_ days: Int, in calendar: Calendar) -> RankingRequest? {
        guard let start = interval(in: calendar)?.start,
            let last = calendar.date(byAdding: .day, value: days - 1, to: start)
        else {
            return nil
        }
        var request = self
        request.granularity = .day
        request.periods = days
        request.date = Self.day(last, in: calendar)
        return request
    }

    /// `date` as `YYYY-MM-DD` in `calendar`.
    static func day(_ date: Date, in calendar: Calendar) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", components.year ?? 0, components.month ?? 0, components.day ?? 0)
    }

    private func lastDate(in calendar: Calendar) -> Date? {
        guard let date else {
            return calendar.startOfDay(for: .now)
        }
        return SiteStats.periodStart(of: date, in: calendar)
    }
}

/// Items with a figure each, highest first, as a stats call that ranks items returns them.
struct RankedList: Sendable {
    struct Row: Sendable {
        let name: String
        let value: Int
    }

    /// What the values count, such as "Views".
    let metricTitle: String
    let rows: [Row]
    /// The total across every item, listed or not, when the call returns one.
    let total: Int?
    /// Whether the values are whole percents rather than counts.
    var isPercentage = false
}
